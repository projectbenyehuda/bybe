# frozen_string_literal: true

require 'English'
class IngestiblesController < ApplicationController
  include LockIngestibleConcern
  include BybeUtils

  # to allow starting ingestions directly from the task system
  skip_before_action :verify_authenticity_token, only: :create

  before_action { |c| c.require_editor('edit_catalog') }
  before_action :set_ingestible,
                only: %i(show edit update update_markdown update_toc destroy review ingest edit_toc update_toc_list
                         undo unlock)
  before_action :try_to_lock_ingestible,
                only: %i(edit update update_markdown destroy review update_toc update_toc_list edit_toc undo)

  DEFAULTS = { title: '', status: 'draft', orig_lang: 'he', default_authorities: [], collection_authorities: [],
               metadata: {}, comments: '', markdown: '' }.freeze
  # GET /ingestibles or /ingestibles.json
  def index
    show_all = params[:show_all] == '1'
    scope = show_all ? Ingestible.all : Ingestible.where.not(status: 'ingested')

    @locked_ingestibles = scope.where('locked_at > ?', 1.hour.ago)
    @my_ingestibles = @locked_ingestibles.where(locked_by_user_id: current_user.id)
    @locked_ingestibles = @locked_ingestibles.where.not(id: @my_ingestibles)

    @other_ingestibles = scope.where.not(id: @locked_ingestibles.pluck(:id)).order(updated_at: :desc).page(params[:page])
    @ingestibles_pending = scope.where(status: 'awaiting_authorities').order(updated_at: :desc)
  end

  # GET /ingestibles/1 or /ingestibles/1.json
  def show
    # before ingestion, editing is the meaningful view
    if @ingestible.awaiting_authorities?
      redirect_to review_ingestible_url(@ingestible)
    else
      unless @ingestible.ingested?
        edit
        render :edit
      else
        @changes = JSON.parse(@ingestible.ingested_changes)
      end
    end
  end

  # GET /ingestibles/new
  def new
    @ingestible = Ingestible.new(DEFAULTS)
  end

  # GET /ingestibles/1/review
  def review
    @markdown_titles = @ingestible.markdown.present? ? @ingestible.markdown.scan(/^&&&\s+(.+?)\s*\n/).map(&:first) : []
    prep_for_ingestion
  end

  # GET /ingestibles/1/undo
  def undo
    changes = JSON.parse(@ingestible.ingested_changes)
    @collection = changes['collections'].present? ? Collection.find(changes['collections'].first[0]) : nil
    changes['texts'].each do |id, _title, _authorstr|
      m = Manifestation.find(id)
      @collection.collection_items.where(item: m).destroy_all unless @collection.nil?
      m.destroy!
    end
    changes['placeholders'].each do |x|
      @collection.collection_items.where(alt_title: x).destroy_all unless @collection.nil?
    end
    # delete the collection IF this ingestion created it AND there are no more items in it (now that we have deleted the ones this ingestion added)
    @collection.destroy! if @collection.present? && changes['collections'].first[2] == 'created' && @collection.collection_items.empty?
    @ingestible.draft!
    redirect_to edit_ingestible_url(@ingestible), notice: t('.undone')
  end

  # PATCH /ingestibles/1/unlock
  def unlock
    if @ingestible.locked_by_user == current_user
      @ingestible.release_lock!
      redirect_to ingestibles_url, notice: t('.success')
    else
      redirect_to ingestibles_url, error: t('.not_locked_by_you')
    end
  end

  # GET /ingestibles/1/ingest
  def ingest
    prep_for_ingestion
    if @errors.present?
      @ingestible.draft! unless @ingestible.draft?
      redirect_to review_ingestible_url(@ingestible), alert: t('.errors')
    elsif @authorities_tbd.present?
      @ingestible.awaiting_authorities!
      redirect_to ingestibles_path, alert: t('.ingestion_now_pending')
    elsif @potential_duplicates.present? && params[:confirm_duplicates] != '1'
      # Block ingestion if duplicates found and not confirmed
      @ingestible.draft! unless @ingestible.draft?
      redirect_to review_ingestible_url(@ingestible), alert: t('.duplicates_found_not_confirmed')
    else
      @failures = []
      @changes = { placeholders: [], texts: [], collections: [] }
      create_or_load_collection unless @ingestible.no_volume # no_volume means we don't want to ingest into a Collection, and @collection would be nil.
      # - loop over whole TOC
      i = 0
      @decoded_toc.each do |x|
        if x[0] == 'yes' # a text to ingest
          upload_text(x, i)
          i += 1
        else # a placeholder
          create_placeholder(x) unless @ingestible.no_volume # placeholders only make sense in volumes
        end
      end
      @ingestible.ingested_changes = @changes.to_json # record all IDs in ingestible, for undoability
      @ingestible.user = current_user # record ingesting user
      if @failures.present?
        @ingestible.status = 'failed'
        @ingestible.problem = '' if @ingestible.problem.nil?
        @ingestible.problem += @failures.join("\n")
        @ingestible.save!
        redirect_to review_ingestible_url(@ingestible), alert: t('.failures')
      else
        @ingestible.status = 'ingested'
        @ingestible.save!
        # - email (whom?) with news about the ingestion, and links to all the created entities
        # - show post-ingestion screen, with links to all created entities and affected authorities
        # Invalidate whatsnew page cache after successful ingestion
        invalidate_whatsnew_cache
        redirect_to ingestible_url(@ingestible), notice: t('.success')
      end
    end
  end

  # GET /ingestibles/1/edit
  def edit
    @ingestible.update_parsing # refresh markdown or text buffers if necessary
    prep(true) # rendering of HTML needed for editing screen
    @tab = params[:tab]
    @authority_by_name = Authority.all.to_h { |a| [a.name, a.id] }
  end

  # POST /ingestibles or /ingestibles.json
  def create
    # TODO: use params to set defaults (callable from the tasks system, which means we can populate the title (=task name), genre, credits)
    @ingestible = Ingestible.new(ingestible_params)
    @ingestible.credits.presence&.gsub!(/\s*;\s*/, "\n")
    @ingestible.update_authorities_and_metadata_from_volume(false) if @ingestible.prospective_volume_id.present?
    if params[:ingestible][:originating_task].present?
      existing = Ingestible.where(originating_task: params[:ingestible][:originating_task])
      if existing.present?
        redirect_to edit_ingestible_url(existing.first), notice: t('ingestible.already_being_ingested')
        return
      end
    end
    if params[:docx].present?
      file = URI.open(params[:docx])
      uri = URI.parse(params[:docx])
      @ingestible.docx.attach(io: file, filename: CGI.unescape(File.basename(uri.path)))
    end
    if @ingestible.save
      redirect_to edit_ingestible_url(@ingestible), notice: t('.success')
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit_toc
    include = false
    toc_buf = []
    @ingestible.decode_toc.each do |x|
      if include && x[0].strip != 'yes'
        include = false
        toc_buf << '$$$ סוף'
      end
      if !include && x[0].strip == 'yes'
        include = true
        toc_buf << '$$$ התחלה'
      end
      toc_buf << x[1]
    end
    @toc_list = toc_buf.join("\n")
    @authority_by_name = Authority.all.to_h { |a| [a.name, a.id] }

    render layout: false
  end

  # PATCH/PUT /ingestibles/1 or /ingestibles/1.json
  def update
    existing_volume_id = @ingestible.volume_id
    existing_prospective_volume_id = @ingestible.prospective_volume_id
    if @ingestible.update(ingestible_params)
      if existing_volume_id != @ingestible.volume_id || existing_prospective_volume_id != @ingestible.prospective_volume_id
        @ingestible.update_authorities_and_metadata_from_volume(true)
      end
      redirect_to edit_ingestible_url(@ingestible), notice: t('.success')
    else
      render :edit, status: :unprocessable_content
    end
  end

  def update_markdown
    markdown_params = params.expect(ingestible: [:markdown])
    # get rid of leading whitespace
    pos = markdown_params['markdown'].index(/\S/)
    markdown_params['markdown'] = markdown_params['markdown'][pos..] if pos.present? && pos > 0

    @ingestible.update!(markdown_params)
    redirect_to edit_ingestible_url(@ingestible, tab: 'full_markdown'), notice: t(:updated_successfully)
  end

  def update_toc
    toc_params = params.permit(%i(title new_title genre orig_lang intellectual_property authority_id authority_name
                                  role new_person_tbd rmauth seqno clear_defaults))
    cur_toc = @ingestible.decode_toc
    updated = false
    prep(false) # prepare the markdown titles for the view
    cur_toc.each do |x|
      next unless x[1] == params[:title] # update the existing entry

      x[1] = toc_params[:new_title] if toc_params[:new_title].present? # allow changing the title
      x[3] = toc_params[:genre] if toc_params[:genre].present?
      x[4] = toc_params[:orig_lang] if toc_params[:orig_lang].present?
      x[5] = toc_params[:intellectual_property] if toc_params[:intellectual_property].present?

      if params[:replaceauth].present?
        authorities = x[2].present? ? JSON.parse(x[2]) : []
        authorities.reject! { |a| a['seqno'] == params[:seqno].to_i }
        x[2] = authorities.to_json
      end
      if params[:new_person_tbd].present? || params[:authority_id].present?
        authorities = x[2].present? ? JSON.parse(x[2]) : []
        highest_seqno = authorities.pluck('seqno').max || 0
        new_authority = { 'seqno' => highest_seqno + 1, 'role' => params[:role] }
        if params[:new_person_tbd].present?
          # Authority not yet present in database
          new_authority['new_person'] = params[:new_person_tbd]
        elsif params[:authority_id].present?
          # Existing authority from database
          new_authority['authority_id'] = params[:authority_id].to_i
          new_authority['authority_name'] = params[:authority_name]
        else
          head :bad_request
          return
        end
        authorities << new_authority
        x[2] = authorities.to_json
      elsif params[:rmauth].present?
        authorities = x[2].present? ? JSON.parse(x[2]) : []
        authorities.reject! { |a| a['seqno'] == params[:seqno].to_i }
        x[2] = authorities.to_json
      elsif params[:clear_defaults].present?
        # Clear default authorities for this specific work by setting an empty array
        x[2] = '[]'
      end

      updated = true
      break
    end
    return unless updated

    @authority_by_name = Authority.all.to_h { |a| [a.name, a.id] }

    @ingestible.update_columns(toc_buffer: @ingestible.encode_toc(cur_toc))
  end

  def update_toc_list
    toc_list = params[:toc_list].split("\n").map(&:strip)
    ret = []
    cur_toc = @ingestible.decode_toc
    include = false
    toc_list.each do |x|
      next if x.blank?

      if x =~ /^\$\$\$ /
        include = x == '$$$ התחלה'
        next
      end
      existing = cur_toc.find { |y| y[1].strip == x }

      ret << if existing.nil?
               " #{include ? 'yes' : 'no'} || #{x} || || #{@ingestible.genre} || #{@ingestible.orig_lang} || #{@ingestible.intellectual_property}" # use ingestible defaults when set
             else
               " #{include ? 'yes' : 'no'} || #{x} || #{existing[2]} || #{existing[3]} || #{existing[4]} || #{existing[5]}" # preserve any existing metadata
             end
    end
    @ingestible.update_columns(toc_buffer: ret.join("\n"))
    redirect_to edit_ingestible_url(@ingestible, tab: 'toc'), notice: t('updated_successfully'), status: :see_other
  end

  # DELETE /ingestibles/1 or /ingestibles/1.json
  def destroy
    @ingestible.destroy
    redirect_to ingestibles_url, notice: t('.success')
  end

  # Autocomplete for authorities in ingestibles#edit form - returns ALL matching results
  def autocomplete_authority_full
    items = ElasticsearchAutocomplete.call(
      params[:term],
      AuthoritiesAutocompleteIndex,
      %i(name other_designation),
      limit: 10_000
    )

    render json: json_for_autocomplete(items, :name)
  end

  # Autocomplete for collections in ingestibles#edit form - returns ALL matching results
  def autocomplete_collection_full
    items = Collection.where('title LIKE ?', "%#{params[:term]}%")
                      .order(:title)
                      .limit(10_000)

    render json: items.map { |c| { id: c.id, label: c.title_and_authors, value: c.title } }
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_ingestible
    @ingestible = Ingestible.find(params[:id])
  end

  def prep(render_html = false)
    @html = ''
    @disable_submit = false
    @markdown_titles = []
    return if @ingestible.works_buffer.blank?

    sections = JSON.parse(@ingestible.works_buffer)
    sections.each_with_index do |section, index|
      title = section['title']
      @markdown_titles << title
      content = section['content']

      next unless render_html

      # markdown_texts = split_parts.map(&:last)
      if title.present? && content.present?
        validator = TitleValidator.new
        dummy = Work.new(title: title.sub(/_ZZ\d+/, ''))
        if validator.validate(dummy)
          doctored_title = title
        else
          doctored_title = "<span style='color:red'>#{title}</span><br><span style='color:red'>#{dummy.errors.full_messages.join('<br />')}</span>"
          @disable_submit = true
        end
      else
        doctored_title = "<span style='color:red'>#{title} #{t(:empty_work_title_or_no_content)}</span>"
      end
      section_html = MarkdownToHtml.call(content)
      # Apply footnote noncer to make footnote anchors unique per section
      section_html = footnotes_noncer(section_html, "md_#{index}")
      @html += "<hr style='border-color:#2b0d22;border-width:20px;margin-top:40px'/><h1>#{doctored_title.sub(/_ZZ\d+/,
                                                                                                             '')}</h1>" + section_html
    end
    @html = highlight_suspicious_markdown(@html) # highlight suspicious markdown in backend
  end

  # this method prepares the ingestible for ingestion:
  # it collects the placeholders to be created according to the toc,
  # it collects the manifestations to be created for the included texts,
  # and it maps the affected involved authorities.
  # It is called by the review action for the user's approval, but also from the actual ingestion action.
  def prep_for_ingestion
    @decoded_toc = @ingestible.decode_toc
    @texts_to_upload = @ingestible.texts_to_upload
    @placeholders = @ingestible.placeholders
    @markdown_titles = @ingestible.markdown.present? ? @ingestible.markdown.scan(/^&&&\s+(.+?)\s*\n/).map(&:first) : []
    @collection = @ingestible.volume # would be nil for new volumes
    @authority_changes = {}
    @missing_in_markdown = []
    @extraneous_markdown = @markdown_titles - @texts_to_upload.map(&:second)
    @missing_genre = []
    @missing_origlang = []
    @missing_authority = []
    @missing_publisher_info = !@ingestible.no_volume && (@ingestible.publisher.blank? || @ingestible.year_published.blank?)
    @authorities_tbd = []
    @missing_translators = []
    @missing_authors = []
    # report on missing authority in collection_authorities
    if @ingestible.collection_authorities.present?
      @coll_aus = JSON.parse(@ingestible.collection_authorities)
      @coll_aus.each do |ia|
        @authorities_tbd << ia if ia['new_person'].present?
      end
    end
    # report on missing authority in default_authorities
    if @ingestible.default_authorities.present?
      @def_aus = JSON.parse(@ingestible.default_authorities)
      @def_aus.each do |ia|
        @authorities_tbd << ia if ia['new_person'].present?
      end
    end
    @texts_to_upload.each do |x|
      @missing_in_markdown << x[1] unless @markdown_titles.include?(x[1])
      @missing_genre << x[1] if x[3].blank?
      # Use per-role merging to compose authorities from explicit and defaults
      aus = merge_authorities_per_role(x[2], @ingestible.default_authorities)
      @missing_authority << x[1] if aus.empty?
      seen_translator = false
      seen_author = false
      aus.each do |ia|
        @authorities_tbd << ia if ia['new_person'].present?
        seen_translator = true if ia['role'] == 'translator'
        seen_author = true if ia['role'] == 'author'
        name = ia['new_person'].presence || ia['authority_name']
        role = ia['role']
        @authority_changes[name] = {} unless @authority_changes.key?(name)
        @authority_changes[name][role] = [] unless @authority_changes[name].key?(role)
        @authority_changes[name][role] << x[1]
      end
      @missing_translators << x[1] if x[4] != 'he' && !seen_translator
      @missing_origlang << x[1] if x[4].blank? || (x[4] == 'he' && seen_translator)
      @missing_authors << x[1] unless seen_author
    end
    @empty_texts = []
    @ingestible.texts.each do |t|
      next if t.content.present? && !t.content.strip.empty?

      @empty_texts << t.title
    end

    # Check for potential duplicates
    @potential_duplicates = []
    @texts_to_upload.each do |toc_line|
      title = toc_line[1]
      authorities_json = toc_line[2]

      # Merge authorities to get the complete list that will be used
      merged_authorities = merge_authorities_per_role(authorities_json, @ingestible.default_authorities)

      # Unescape title for comparison - titles are stored unescaped in the database
      unescaped_title = unescape_markdown_title(title)

      # Find manifestations with the same title and eager load authorities to avoid N+1 queries
      existing_manifestations = Manifestation.where(title: unescaped_title).with_involved_authorities

      existing_manifestations.each do |manifestation|
        # Get involved authorities for this manifestation
        existing_involved = manifestation.involved_authorities

        # Compare authorities - check if they match
        next unless same_authorities?(merged_authorities, existing_involved)

        @potential_duplicates << {
          title: unescaped_title,
          manifestation_id: manifestation.id,
          manifestation_url: url_for(controller: :manifestation, action: :read, id: manifestation.id, only_path: true)
        }
      end
    end

    # Remove duplicate entries (same manifestation found for multiple texts)
    @potential_duplicates.uniq! { |d| d[:manifestation_id] }

    @errors = @missing_in_markdown.present? || @extraneous_markdown.present? || @missing_genre.present? || @missing_origlang.present? || @missing_authority.present? || @missing_translators.present? || @missing_authors.present? || @missing_publisher_info || @empty_texts
  end

  # Only allow a list of trusted parameters through.
  def ingestible_params
    params.expect(
      ingestible: %i(title
                     status
                     scenario
                     genre
                     publisher
                     year_published
                     orig_lang
                     intellectual_property
                     periodical_id
                     docx
                     metadata
                     comments
                     no_volume
                     attach_photos
                     problem
                     prospective_volume_id
                     prospective_volume_title
                     pub_link
                     pub_link_text
                     toc_buffer
                     credits
                     originating_task
                     project_id
                     tasks_project_id)
    )
  end

  def create_or_load_collection
    created_volume = false
    if @ingestible.prospective_volume_id.present?
      if @ingestible.prospective_volume_id[0] == 'P' # new volume from known Publication
        @publication = Publication.find(@ingestible.prospective_volume_id[1..])
        @collection = Collection.find_by(publication: @publication) # might have been created by another ingestion while we we working on this, after identifying the publication...
        if @collection.nil? # new volume from known Publication
          publine = @ingestible.publisher.presence || @publication.publisher_line
          pubyear = @ingestible.year_published.presence || @publication.pub_year
          volume_title = @ingestible.prospective_volume_title.presence || @publication.title
          @collection = Collection.create!(title: volume_title,
                                           collection_type: 'volume', publication: @publication,
                                           publisher_line: publine, pub_year: pubyear)
          created_volume = true
        end
      else # existing volume
        @collection = Collection.find(@ingestible.prospective_volume_id)
      end
    else # new volume from scratch!
      @collection = Collection.create!(title: @ingestible.prospective_volume_title, collection_type: 'volume',
                                       pub_year: @ingestible.year_published, publisher_line: @ingestible.publisher)
      created_volume = true
    end
    # Populate publisher info if not already set (e.g. in new periodical issue)
    # Don't set publisher_line/pub_year for series collections (series are groups of
    # manifestations within a volume, not publications themselves)
    if @ingestible.publisher.present? && @collection.publisher_line.blank? && @collection.collection_type != 'series'
      @collection.publisher_line = @ingestible.publisher
      @collection.pub_year = @ingestible.year_published
    end
    creds = @collection.credits.presence || ''
    creds += "\n" + @ingestible.credits if @ingestible.credits.present?
    credits = creds.lines.map(&:strip).uniq.reject { |x| x == '...' }.join("\n")
    @collection.credits = credits
    @collection.save!
    @changes[:collections] << [@collection.id, @collection.title, created_volume ? 'created' : 'updated'] # record the new volume for the post-ingestion screen

    # Add publisher external link from project if present
    # Check if this link already exists on the collection
    if @ingestible.project.present? && @ingestible.project.default_external_link.present? && !@collection.external_links.exists?(linktype: :publisher_site,
                                                                                                                                 url: @ingestible.project.default_external_link)
      @collection.external_links.create!(
        linktype: :publisher_site,
        url: @ingestible.project.default_external_link,
        description: @ingestible.project.default_link_description
      )
    end

    # Add collection-level involved authorities (whether new or existing collection)
    return if @ingestible.collection_authorities.blank?

    JSON.parse(@ingestible.collection_authorities).each do |auth|
      next if auth['authority_id'].blank? # skip authorities not yet in database

      # Check if this authority+role combination already exists on the collection
      existing = @collection.involved_authorities.find_by(
        authority_id: auth['authority_id'],
        role: auth['role']
      )
      next if existing.present?

      @collection.involved_authorities.create!(
        authority: Authority.find(auth['authority_id']),
        role: auth['role']
      )
    end
  end

  # determine period by most common one among relevant involved authorities
  def determine_period_by_involved_authorities(ids)
    periods = []
    Authority.find(ids).each do |a|
      periods << a.person.period if a.person.present?
    end
    return periods.present? ? periods.max_by { |i| periods.count(i) } : nil
  end

  # status defaults to published, but if even one authority is unpublished, text will be unpublished
  def determine_publication_status_by_involved_authorities(ids)
    status = :published
    Authority.find(ids).each do |a|
      status = :unpublished unless a.published?
    end
    status
  end

  # add a placeholder (itemless CollectionItem) to the collection
  def create_placeholder(toc_line)
    unescaped_title = unescape_markdown_title(toc_line[1])
    return if @collection.collection_items.where(alt_title: unescaped_title).present? # don't create duplicate placeholders. It is expected they are unique within the collection. Genuine duplicate titles that the user DOES want created should have been disambiguated at the review phase.

    @collection.append_collection_item(CollectionItem.new(alt_title: unescaped_title))
    @changes[:placeholders] << unescaped_title
  end

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
    work_roles = work_auths.pluck('role').uniq

    # Start with work authorities, then add defaults for roles not present in work authorities
    result = work_auths.dup
    default_auths.each do |default_auth|
      unless work_roles.include?(default_auth['role'])
        result << default_auth
      end
    end

    result
  end

  # Compare if two sets of authorities are the same
  # merged_authorities is an array of hashes from TOC
  # existing_involved is an array of InvolvedAuthority records
  def same_authorities?(merged_authorities, existing_involved)
    # Filter out authorities without IDs (new_person entries)
    # and build sets of (authority_id, role) pairs for comparison
    toc_authorities_set = merged_authorities
                          .select { |auth| auth['authority_id'].present? }
                          .to_set { |auth| [auth['authority_id'].to_i, auth['role']] }

    existing_authorities_set = existing_involved.to_set do |ia|
      [ia.authority_id, ia.role]
    end

    # They match if both sets are non-empty and equal
    return false if toc_authorities_set.empty? || existing_authorities_set.empty?

    toc_authorities_set == existing_authorities_set
  end

  def upload_text(toc_line, index)
    # create Work, Expression, Manifestation entities

    Chewy.strategy(:atomic) do
      ActiveRecord::Base.transaction do
        unescaped_title = unescape_markdown_title(toc_line[1])
        w = Work.new(
          title: unescaped_title,
          orig_lang: toc_line[4],
          genre: toc_line[3],
          primary: true # TODO: un-hardcode primariness when ingestible TOC editing supports it
        )
        author_names = []
        author_ids = []
        translator_names = []
        translator_ids = []
        other_authorities = []
        # Merge authorities per role: specific authorities override defaults for their role only
        auths = merge_authorities_per_role(toc_line[2], @ingestible.default_authorities)
        auths.each do |ia|
          if ia['role'] == 'author'
            author_names << ia['authority_name']
            author_ids << ia['authority_id']
          elsif ia['role'] == 'translator'
            translator_names << ia['authority_name']
            translator_ids << ia['authority_id']
          else
            other_authorities << [ia['authority_id'], ia['role']]
          end
        end
        # translator's period is the relevant one for translations
        period = determine_period_by_involved_authorities(w.orig_lang == 'he' ? author_ids : translator_ids)
        all_authority_ids = author_ids + translator_ids + other_authorities.map(&:first)
        pub_status = determine_publication_status_by_involved_authorities(all_authority_ids)

        # Calculate copyright status and set intellectual property accordingly
        calculated_copyright = @ingestible.calculate_copyright_status(toc_line[2])
        intellectual_property_value = if calculated_copyright == 'public_domain'
                                        'public_domain'
                                      else
                                        # Use the selected value from TOC, or default from ingestible
                                        toc_line[5].presence || @ingestible.intellectual_property || 'by_permission'
                                      end

        e = w.expressions.build(
          title: unescaped_title,
          language: 'he',
          period: period, # what to do if corporate body?
          intellectual_property: intellectual_property_value,
          source_edition: @ingestible.publisher,
          date: @ingestible.year_published
        )
        authors = auths.select { |ia| ia['role'] == 'author' }.map { |ia| ia['authority_name'] }
        translators = auths.select { |ia| ia['role'] == 'translator' }.map { |ia| ia['authority_name'] }.join(', ')
        responsibility_line = translators.present? ? translator_names.join(', ') : authors.join(', ')
        # the_markdown = @ingestible.markdown.scan(/^&&&\s+#{toc_line[1]}\s*\n(.+?)(?=\n&&&|$)/m).first.first
        m = e.manifestations.build(
          title: unescaped_title,
          responsibility_statement: responsibility_line,
          conversion_verified: true,
          medium: I18n.t(:etext),
          publisher: Rails.configuration.constants['our_publisher'],
          publication_place: Rails.configuration.constants['our_place_of_publication'],
          publication_date: Time.zone.today,
          markdown: @ingestible.texts[index].content,
          status: pub_status,
          credits: @ingestible.credits.lines.map(&:strip).uniq.join("\n")
        )
        w.save!
        auths = []
        # associate authorities
        Authority.find(author_ids).each do |a|
          w.involved_authorities.create!(authority: a, role: :author)
          auths << a
        end
        Authority.find(translator_ids).each do |a|
          e.involved_authorities.create!(authority: a, role: :translator)
          auths << a
        end
        Authority.find(other_authorities.map(&:first)).each_with_index do |auth, i|
          e.involved_authorities.create!(authority: auth, role: other_authorities[i][1])
          auths << auth
        end
        auths.uniq.each do |a|
          a.invalidate_cached_credits!
          a.invalidate_cached_works_count!
        end
        @changes[:texts] << [m.id, m.title, m.responsibility_statement]
        m.recalc_cached_people!

        # Add publisher external link from project if present
        if @ingestible.project.present? && @ingestible.project.default_external_link.present? && !m.external_links.exists?(
          linktype: :publisher_site, url: @ingestible.project.default_external_link
        )
          m.external_links.create!(
            linktype: :publisher_site,
            url: @ingestible.project.default_external_link,
            description: @ingestible.project.default_link_description
          )
        end

        # Add publisher link from ingestible form if present (takes priority/is additional)
        if @ingestible.pub_link.present? && @ingestible.pub_link_text.present?
          m.external_links.create!(linktype: :publisher_site, url: @ingestible.pub_link,
                                   description: @ingestible.pub_link_text)
        end

        unless @ingestible.no_volume
          # finally, add to collection, replacing placeholder if appropriate
          placeholder = @collection.collection_items.reload.where(alt_title: unescaped_title, item: nil)
          if placeholder.present? # we will insert the item just below the placeholder
            # Use the insertion logic from CollectionItemsController#drag_item
            items = @collection.collection_items.order(:seqno).to_a
            placeholder_index = items.index(placeholder.first)
            if placeholder_index.nil?
              # Placeholder not found in items array, fall back to append
              @collection.append_item(m)
            else
              # Create new collection item for the manifestation
              # seqno will be set during resequencing
              new_item = CollectionItem.new(item: m, collection: @collection, seqno: 0)
              # Insert just below the placeholder (placeholder_index + 1)
              items.insert(placeholder_index + 1, new_item)
              # Resequence all items (with optimization from CollectionItemsController#update_seqno)
              items.each_with_index do |ci, index|
                next if ci.seqno == index + 1

                ci.seqno = index + 1
                ci.save(validate: false)
              end
            end
          else
            @collection.append_item(m) # append the new text to the (current) end of the collection if there were no placeholders already
          end
          @collection.invalidate_cached_credits!
        end
      end
    end
  rescue StandardError
    @failures << "#{toc_line[1]} - #{$ERROR_INFO}"
    return I18n.t(:frbrization_error)
  end

  # Remove markdown escape backslashes from title text
  # Pandoc escapes special characters when converting DOCX to markdown,
  # but these backslashes should not be stored in the database
  def unescape_markdown_title(title)
    title.gsub(/\\([\[\]\*\_\{\}\(\)\#\+\-\.\!'])/, '\1')
  end

  def invalidate_whatsnew_cache
    # Delete cache for all sort orders and locales
    %w(alpha recent).each do |sort_order|
      I18n.available_locales.each do |locale|
        Rails.cache.delete(%w(whatsnew_data) + [sort_order, locale.to_s])
      end
    end
  end
end
