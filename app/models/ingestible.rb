# frozen_string_literal: true

require 'pandoc-ruby' # for generic DOCX-to-HTML conversions
require 'set'

# Ingestible is a set of text being prepared for inclusion into a main database
class Ingestible < ApplicationRecord
  LOCK_TIMEOUT_IN_SECONDS = 60 * 15 # 15 minutes
  COPYRIGHTED_IP_OPTIONS = %w(by_permission orphan).freeze

  enum :status, { draft: 0, ingested: 1, failed: 2, awaiting_authorities: 3 }
  enum :scenario, { single: 0, multiple: 1, mixed: 2 }

  belongs_to :user, optional: true
  belongs_to :locked_by_user, class_name: 'User', optional: true
  belongs_to :last_editor, class_name: 'User', optional: true
  belongs_to :volume, optional: true, class_name: 'Collection'
  belongs_to :project, optional: true

  DEFAULTS_SCHEMA = {}.freeze
  validates :title, presence: true
  validates :status, presence: true
  validates :locked_at, presence: true, if: -> { locked_by_user.present? }
  validates :locked_at, absence: true, unless: -> { locked_by_user.present? }
  validate :volume_decision
  validate :check_duplicate_volume, if: :should_check_duplicate_volume?
  #  validates :scenario, presence: true
  #  validates :scenario, inclusion: { in: scenarios.keys }

  has_one_attached :docx # ActiveStorage

  before_save :update_timestamps
  before_create :init_timestamps

  # after_commit :update_parsing # this results in ActiveStorage::FileNotFoundError in dev/local storage

  before_save do
    if @texts.present?
      self.works_buffer = @texts.map(&:to_hash).to_json
    end
  end

  def volume_decision
    return if no_volume

    return unless volume_id.blank? && prospective_volume_id.blank? && prospective_volume_title.blank?

    errors.add(:volume_id,
               'must be present if no_volume is false')
  end

  def creating_new_volume?
    return false if no_volume
    return false if volume_id.present? # Using existing volume
    return false if prospective_volume_id.present? && prospective_volume_id[0] != 'P' # Loading existing collection
    # Don't validate during or after ingestion - only during draft/awaiting_authorities
    return false if ingested? || failed?
    return true if prospective_volume_title.present? # Creating from scratch
    return true if prospective_volume_id.present? && prospective_volume_id[0] == 'P' # Creating from Publication

    false
  end

  def should_check_duplicate_volume?
    # Only check for duplicates if we're creating a new volume
    return false unless creating_new_volume?

    # Parse authorities to check if any are present
    begin
      auths = collection_authorities.present? ? JSON.parse(collection_authorities) : []
      has_authorities = auths.present?

      # For updates: validate if authorities are present AND relevant fields changed
      if persisted?
        relevant_fields_changed = collection_authorities_changed? ||
                                  prospective_volume_title_changed? ||
                                  prospective_volume_id_changed?
        return has_authorities && relevant_fields_changed
      end

      # For new records: only validate if authorities are specified
      # This allows creating an ingestible with a volume title but no authorities,
      # deferring the duplicate check until authorities are added
      return has_authorities
    rescue JSON::ParserError
      # If JSON is invalid, let the other validation handle it
      return false
    end
  end

  def check_duplicate_volume
    # Parse collection authorities for comparison
    begin
      col_auths = collection_authorities.present? ? JSON.parse(collection_authorities) : []
    rescue JSON::ParserError => e
      Rails.logger.error("Invalid JSON in collection_authorities for ingestible #{id}: #{e.message}")
      errors.add(:collection_authorities, I18n.t('ingestible.errors.invalid_collection_authorities_json'))
      return
    end

    # Determine what we're checking against
    if prospective_volume_id.present? && prospective_volume_id[0] == 'P'
      # Creating from Publication - check if volume for this publication already exists
      publication = Publication.find_by(id: prospective_volume_id[1..])
      return if publication.nil? # Invalid publication ID, let other validations handle it

      existing_volume = Collection.find_by(publication: publication)
      if existing_volume && authorities_match?(existing_volume.involved_authorities, col_auths)
        errors.add(:prospective_volume_id, I18n.t('ingestible.errors.duplicate_volume_for_publication'))
        return
      end
    else
      # Creating from scratch - check by title
      return if prospective_volume_title.blank?

      existing_volumes = Collection.where(collection_type: 'volume', title: prospective_volume_title)
      existing_volumes.each do |volume|
        if authorities_match?(volume.involved_authorities, col_auths)
          errors.add(:prospective_volume_title, I18n.t('ingestible.errors.duplicate_volume_by_title'))
          return
        end
      end
    end

    # Check for other Ingestibles with same prospective volume
    other_ingestibles = Ingestible.where(status: [:draft, :awaiting_authorities])
                                   .where.not(id: id) # Exclude current ingestible

    if prospective_volume_id.present? && prospective_volume_id[0] == 'P'
      other_ingestibles = other_ingestibles.where(prospective_volume_id: prospective_volume_id)
    else
      other_ingestibles = other_ingestibles.where(prospective_volume_title: prospective_volume_title)
    end

    other_ingestibles.each do |ingestible|
      if authorities_match_json?(ingestible.collection_authorities, collection_authorities)
        errors.add(:base, I18n.t('ingestible.errors.another_ingestible_proposing_volume'))
        return
      end
    end
  end

  def encode_toc(lines)
    return lines.map { |x| x.join('||') }.join("\n")
  end

  def decode_toc
    return [] if toc_buffer.blank?

    return toc_buffer.lines.map(&:strip).reject(&:empty?).map { |x| x.split('||').map(&:strip) }
  end

  def texts_to_upload
    return decode_toc.select { |x| x[0].strip == 'yes' }
  end

  def placeholders
    return decode_toc.select { |x| x[0].strip == 'no' }
  end

  def multiple_works?
    return markdown =~ /^&&& / # the magic marker for a new work
  end

  def init_timestamps
    self.markdown_updated_at = Time.zone.now
    self.works_buffer_updated_at = Time.zone.now
  end

  def update_timestamps
    return unless markdown_changed?

    self.markdown_updated_at = Time.zone.now
  end

  def update_parsing
    if docx.attached? && (markdown.blank? || docx.attachment.created_at > markdown_updated_at)
      self.markdown = convert_to_markdown
    end

    update_buffers if works_buffer.nil? || markdown_updated_at > works_buffer_updated_at
    save if changed?
  end

  def update_authorities_and_metadata_from_volume(replace_publisher = false)
    # reset *collection* authorities and metadata on any volume change, to avoid accidental carryover
    self.collection_authorities = ''
    aus = []
    seqno = 1
    if volume_id.present?
      volume = Collection.find(volume_id)
      volume.involved_authorities.each do |ia|
        aus << { seqno: seqno, authority_id: ia.authority.id, authority_name: ia.authority.name, role: ia.role }
        seqno += 1
      end
      if replace_publisher
        self.publisher = volume.publisher_line
        self.year_published = volume.pub_year
      end
    elsif prospective_volume_id.present?
      if prospective_volume_id[0] == 'P'
        pub = Publication.find(prospective_volume_id[1..])
        if replace_publisher || publisher.blank?
          self.publisher = pub.publisher_line
          self.year_published = pub.pub_year
        end
        # populate with default role of author, though this would be false when the Hebrew author
        # is the translator of a foreign work. Such cases would need to be corrected manually.
        aus << { seqno: seqno, authority_id: pub.authority.id, authority_name: pub.authority.name, role: 'author' }
      else
        volume = Collection.find(prospective_volume_id)
        self.publisher = volume.publisher_line
        self.year_published = volume.pub_year
        volume.involved_authorities.each do |ia|
          aus << { seqno: seqno, authority_id: ia.authority.id, authority_name: ia.authority.name, role: ia.role }
          seqno += 1
        end
      end
    end
    return if aus.blank?

    self.collection_authorities = aus.to_json
    # Mirror to default authorities if they haven't been manually changed
    mirror_collection_to_default_authorities if should_mirror_authorities?
    # Only save if record is already persisted (exists in database)
    # For new records, let the controller's save handle validation
    save! if persisted?
  end

  # Check if we should mirror collection authorities to default authorities
  # Only mirror if default_authorities is blank or hasn't been manually modified
  def should_mirror_authorities?
    # If default_authorities is blank or identical to old collection_authorities, allow mirroring
    default_authorities.blank? || default_authorities == collection_authorities_was
  end

  # Mirror collection authorities to default authorities
  def mirror_collection_to_default_authorities
    self.default_authorities = collection_authorities
  end

  def convert_to_markdown
    return unless docx.attached?

    bin = docx.download # grab the docx binary

    # Fix inherited formatting (bold/italic from paragraph styles) before pandoc conversion
    # This ensures pandoc can see formatting that's defined in styles but not directly on runs
    bin = FixDocxInheritedFormatting.call(bin)

    tmpfile = Tempfile.new(['docx2mmd__', '.docx'], encoding: 'ascii-8bit')
    tmpfile_pp = Tempfile.new(['docx2mmd__pp_', '.docx'], encoding: 'ascii-8bit')
    begin
      tmpfile.write(bin)
      tmpfile.flush
      tmpfilename = tmpfile.path

      # preserve linebreaks to post-process after Pandoc!
      doc = Docx::Document.open(tmpfilename)
      doc.paragraphs.each do |p|
        p.text = '&&STANZA&&' if p.text.empty? # replaced with <br> tags in postprocess
      end
      doc.save(tmpfile_pp.path) # save modified version

      # limit memory use in production; otherwise severe server hangs possible
      mem_limit = Rails.env.development? ? '' : ' -M2200m '
      markdown = `pandoc +RTS #{mem_limit} -RTS -f docx -t markdown_mmd #{tmpfile_pp.path} 2>&1`
      #      markdown = `pandoc +RTS #{mem_limit} -RTS -f docx -t markdown_mmd #{tmpfile.path} 2>&1`
      raise 'Heap exhausted' if markdown =~ /pandoc: Heap exhausted/

      self.markdown_updated_at = Time.zone.now
      return postprocess(markdown)

    # docx too large for pandoc with mem_limit
    rescue StandardError
      raise 'Conversion error'
    ensure
      tmpfile.close
    end
  end

  # copied from HtmlFileController's new_postprocess
  def postprocess(buf)
    # remove all SPAN tags left by pandoc from buf
    buf = buf.gsub(/<span[^>]*>/m, '').gsub('</span>', '')
    lines = buf.split("\n")
    in_footnotes = false
    prev_nikkud = false
    (0..(lines.length - 1)).each do |i|
      lines[i].strip!
      if lines[i].empty? && prev_nikkud
        lines[i] = '> '
        next
      end
      uniq_chars = lines[i].gsub(/[\s\u00a0]/, '').chars.uniq
      if (uniq_chars == ['*']) || (uniq_chars == ["\u2013"]) # if the line only contains asterisks/En-Dash (U+2013)
        lines[i] = '***' # make it a Markdown horizontal rule
        prev_nikkud = false
      else
        nikkud = is_full_nikkud(lines[i])
        # once reached the footnotes section, set the footnotes mode to properly handle multiline footnotes with tabs
        in_footnotes = true if lines[i] =~ /^\[\^\d+\]:/
        if nikkud
          # make full-nikkud lines PRE
          # Only add > if line doesn't already start with > (prevent > appearing mid-line after joining)
          unless (lines[i] =~ /\[\^\d+/) || title_line(lines[i]) || (lines[i] =~ /^\s*>/)
            lines[i] = "> #{lines[i]}"
          end
          prev_nikkud = true
        else
          prev_nikkud = false
        end
        if in_footnotes && lines[i] !~ /^\[\^\d+\]:/ # add a tab for multiline footnotes
          lines[i] = "\t#{lines[i]}"
        end
      end
    end
    # join the lines back together, keeping only one '>' character at the start of paragraphs, i.e. removing '>' from consecutive lines that are being joined to a line already starting with '>'
    new_buffer = lines.join("\n")
    new_buffer.gsub!("\n\s*\n\s*\n", "\n\n")
    ['.', ',', ':', ';', '?', '!'].each do |c|
      new_buffer.gsub!(" #{c}", c) # remove spaces before punctuation
    end
    new_buffer.gsub!(/> (.*?)\n\s*\n\s*\n/, "> \\1\n> \n<br />\n> \n") # add <br> tags for poetry to preserve stanza breaks
    new_buffer.gsub!('&&STANZA&&', "\n> \n<br />\n> \n") # sigh
    new_buffer.gsub!('&amp;&amp;STANZA&amp;&amp;', "\n> \n<br />\n> \n") # sigh
    new_buffer.gsub!(%r{(\n\s*)*\n> \n<br />\n> (\n\s*)*}, "\n> \n<br />\n> \n\n") # sigh
    new_buffer.gsub!(/\n> *> +/, "\n> ") # we basically never want this super-large indented poetry
    new_buffer.gsub!(/\n\s*\n> *\n> /, "\n> \n> ") # remove extra newlines before verse lines
    new_buffer.gsub!('> <br />', '<br />') # remove PRE from line-break, which confuses the markdown processor
    return new_buffer
  end

  def title_line(s)
    (s =~ /^\#{1,6}\s+/) || (s =~ /^&&&\s+/)
  end

  # split markdown into sections and populate or update the works_buffer
  def update_buffers
    return if markdown.blank?

    buf = []
    sections = markdown.split(/^&&& /)

    sections.each do |section|
      # skip the first match if no text appeared before the first &&&
      next if section.blank?

      lines = section.lines
      title = lines.first
      title.presence&.strip!
      content = lines[1].nil? ? [] : lines[1..].map(&:strip)
      buf << { title: title, content: content.present? ? content.join("\n") : '' } if title.present?
    end

    if multiple_works? && markdown =~ /\[\^\d+\]/ # if there are footnotes in the text
      footnotes_fixed_buffers = relocate_footnotes.map { |_k, v| v }
      buf.each_index do |i|
        buf[i][:content] = footnotes_fixed_buffers[i]
      end
    end
    self.works_buffer = buf.to_json
    self.works_buffer_updated_at = Time.current
    save
  end

  def texts
    # TODO: invalidate memoized value
    @texts ||= works_buffer.nil? ? [] : JSON.parse(works_buffer).map { |json| IngestibleText.new(json) }
  end

  # iterate through texts and move the footnotes belonging to each segment over to where they belong
  # it seems a waste to do on each load, but because of possibly *changing* boundaries of texts
  # (as mistakes are discovered and the full markdown is manually edited), it's best to do it on each load.
  # this implementation is copied from HtmlFile.rb; had no time to harmonize with update_buffers above
  def relocate_footnotes
    return if markdown.blank?

    prev_key = nil
    titles_order = []
    ret = {}
    footbuf = ''
    i = 1
    markdown.split(/^(&&& .*)/).each do |bit|
      if bit[0..3] == '&&& '
        prev_key = "#{bit[4..].strip}_ZZ#{i}" # remember next section's title
        stop = false
        loop do
          if prev_key =~ /\[\^\d+\]/ # if the title line has a footnote
            footbuf += ::Regexp.last_match(0) # store the footnote
            prev_key.sub!(::Regexp.last_match(0), '').strip! # and remove it from the title
          else
            stop = true
          end
          break if stop
        end
      else
        ret[prev_key] = footbuf + bit unless prev_key.nil? # buffer the text to be put in the prev_key next iteration
        titles_order << prev_key unless prev_key.nil?
        footbuf = ''
      end
      i += 1
    end
    # great! now we have the different pieces sorted, *but* any footnotes are *only* in the last piece, even if they belong in earlier pieces. So we need to fix that.
    footnotes_by_key = {}
    ret.keys.map { |k| footnotes_by_key[k] = ret[k].scan(/\[\^\d+\][^:]/).map { |line| line[0..-2] } }
    # now that we know which ones belong where, we can move them over
    titles_order.each do |key|
      next if key == titles_order[-1] # last one needs no handling
      next if footnotes_by_key[key].nil?

      buf = ''
      footnotes_by_key[key].each do |foot|
        ret[titles_order[-1]] =~ /(#{Regexp.quote(foot.strip)}:.*?)\[\^\d+\]/m # grab the entire footnote, right up to the next one, into $1
        unless ::Regexp.last_match(1)
          # okay, it may *be* the last/only one...
          ret[titles_order[-1]] =~ /(#{Regexp.quote(foot.strip)}:.*)/m # grab the rest of the doc
        end
        next unless ::Regexp.last_match(1) # shouldn't happen in DOCX conversion, but with manual markdown, anything is possible

        buf += ::Regexp.last_match(1) # and buffer it
        ret[titles_order[-1]].sub!(::Regexp.last_match(1), '') # and remove it from the final chunk's footnotes, where it does not belong
      end
      ret[key] += "\n" + buf
    end
    return ret
  end

  def locked?
    locked_at.present? && locked_at > LOCK_TIMEOUT_IN_SECONDS.seconds.ago
  end

  def obtain_lock(user)
    return false if locked? && locked_by_user_id != user.id

    # To avoid excessive updates we only refresh lock if more than 10 seconds passed since previous lock refresh
    if locked_at.nil? || locked_at < 10.seconds.ago
      update_columns(locked_at: Time.zone.now, locked_by_user_id: user.id, last_editor_id: user.id) # we deliberately skip validations here
    end

    return true
  end

  def release_lock!
    update_columns(locked_at: nil, locked_by_user_id: nil) # we deliberately skip validations here
  end

  # Calculate expected copyright status based on involved authorities
  # Returns 'public_domain' if all authorities are public_domain, 'copyrighted' otherwise
  # @param text_authorities [String] JSON string of text-specific authorities
  # @return [String] 'public_domain' or 'copyrighted'
  def calculate_copyright_status(text_authorities)
    # Merge authorities per role to get the complete list
    merged_authorities = merge_authorities_per_role(text_authorities, default_authorities)

    # Also include collection authorities as they may be relevant
    collection_auths = collection_authorities.present? ? JSON.parse(collection_authorities) : []

    # Collect all authority IDs that need to be checked
    authority_ids = []
    merged_authorities.each do |auth|
      authority_ids << auth['authority_id'] if auth['authority_id'].present?
    end
    collection_auths.each do |auth|
      authority_ids << auth['authority_id'] if auth['authority_id'].present?
    end

    # If no authorities with IDs, we can't determine status - return copyrighted to be safe
    return 'copyrighted' if authority_ids.empty?

    # Check if any authority is not public_domain
    # More efficient than loading all records
    has_non_public_domain = Authority.where(id: authority_ids.uniq)
                                     .where.not(intellectual_property: :public_domain)
                                     .exists?

    has_non_public_domain ? 'copyrighted' : 'public_domain'
  end

  private

  # Merge work-specific authorities with defaults per role
  # If a role is specified in work authorities, it overrides the default for that role
  # If a role is not specified in work authorities, the default for that role is used
  # If work authorities is '[]', no defaults are used (explicit empty)
  def merge_authorities_per_role(work_authorities, default_authorities)
    # Handle explicit empty array - no defaults should apply
    return [] if work_authorities == '[]'

    work_auths = work_authorities.present? ? JSON.parse(work_authorities) : []
    default_auths = default_authorities.present? ? JSON.parse(default_authorities) : []

    # If no defaults, just return work authorities
    return work_auths if default_auths.empty?

    # Get roles present in work authorities
    work_roles = work_auths.map { |a| a['role'] }.uniq

    # Start with work authorities, then add defaults for roles not present in work authorities
    result = work_auths.dup
    default_auths.each do |default_auth|
      unless work_roles.include?(default_auth['role'])
        result << default_auth
      end
    end

    result
  end

  # Check if a collection's involved_authorities match the provided JSON authorities
  def authorities_match?(involved_authorities, json_authorities)
    # Convert involved_authorities to comparable format (set of [authority_id, role] pairs)
    ia_set = involved_authorities.map { |ia| [ia.authority_id, ia.role] }.to_set

    # Convert JSON authorities to comparable format
    json_set = json_authorities.map { |a| [a['authority_id'], a['role']] }.to_set

    ia_set == json_set
  end

  # Check if two JSON authority strings match
  def authorities_match_json?(json_authorities1, json_authorities2)
    # Handle blank cases
    return true if json_authorities1.blank? && json_authorities2.blank?
    return false if json_authorities1.blank? || json_authorities2.blank?

    # Parse and compare
    begin
      auths1 = JSON.parse(json_authorities1).map { |a| [a['authority_id'], a['role']] }.to_set
      auths2 = JSON.parse(json_authorities2).map { |a| [a['authority_id'], a['role']] }.to_set

      auths1 == auths2
    rescue JSON::ParserError => e
      Rails.logger.error("Invalid JSON in authorities comparison: #{e.message}")
      false # If JSON is invalid, consider them as not matching
    end
  end
end
