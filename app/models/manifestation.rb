# frozen_string_literal: true

include BybeUtils

# Class representing Manifestation (actual text) of a Work's Expression
class Manifestation < ApplicationRecord
  include TrackingEvents
  include SortedTitle
  include DownloadLink

  paginates_per 100
  belongs_to :expression, inverse_of: :manifestations
  has_and_belongs_to_many :html_files
  has_and_belongs_to_many :likers, join_table: :work_likes, class_name: :User

  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings, class_name: 'Tag'
  has_many :featured_contents, dependent: :destroy

  has_many :recommendations, dependent: :destroy
  has_many :bookmarks, dependent: :destroy

  has_many :list_items, as: :item, dependent: :destroy
  has_many :downloadables, as: :object, dependent: :destroy

  has_paper_trail ignore: %i(impressions_count created_at updated_at), skip: [:touch]
  has_many :external_links, as: :linkable, dependent: :destroy
  has_many :proofs, as: :item, dependent: :destroy
  has_many :anthology_texts, dependent: :destroy
  has_many_attached :images, dependent: :destroy
  has_many :collection_items, as: :item, dependent: :destroy
  # Where requests for this Manifestation are sent once it has been soft-deleted (status :deprecated).
  belongs_to :soft_redirect_target, class_name: 'Manifestation', foreign_key: :soft_redirect,
                                    inverse_of: false, optional: true
  before_save :update_alternate_titles, if: :title_changed?
  before_save :recalc_cached_people, if: :expression_id_changed?
  before_save :recalc_responsibility_statement, if: :expression_id_changed?
  before_save :recalc_word_count, if: :markdown_changed?

  enum :status, { published: 0, nonpd: 1, unpublished: 2, deprecated: 3 }

  scope :all_published, -> { where(status: Manifestation.statuses[:published]) }
  scope :new_since, ->(since) { where('manifestations.created_at > ?', since) }
  scope :not_translations, -> { joins(:expression).includes(:expression).where(expressions: { translation: false }) }
  scope :translations, -> { joins(:expression).includes(:expression).where(expressions: { translation: true }) }
  scope :genre, ->(genre) { joins(expression: :work).where(works: { genre: genre }) }
  scope :tagged_with, lambda { |tag_id|
                        joins(:taggings).where(taggings: { tag_id: tag_id, status: Tagging.statuses[:approved] }).distinct
                      }
  scope :with_involved_authorities, lambda {
    preload(expression: { involved_authorities: :authority, work: { involved_authorities: :authority } })
  }
  scope :indexable, -> { where(exclude_from_index: false) }

  SHORT_LENGTH = 1500 # kind of arbitrary...
  LONG_LENGTH = 15_000 # kind of arbitrary...

  # Queue of texts flagged by DetectSuspectedTypos, rebuilt weekly by
  # .update_suspected_typos_list; `extra` holds a '<type>:<count>;...' tally.
  SUSPECTED_TYPOS_LISTKEY = 'suspected_typos'
  # An editor's verdict that a flagged text is in fact correct. Kept in its own list so that
  # rebuilding the queue never discards it.
  SUSPECTED_TYPOS_OKAY_LISTKEY = 'suspected_typos_okay'
  # Single-row marker holding, in `extra`, the ISO8601 watermark that .update_suspected_typos_list
  # scanned through. Later runs only look at texts modified since.
  SUSPECTED_TYPOS_LAST_RUN_LISTKEY = 'suspected_typos_last_run'

  # A soft-deletion refuses an already-deprecated target, but a target can be deprecated later on,
  # leaving a chain to walk. Capped because nothing prevents a chain from closing into a cycle.
  SOFT_REDIRECT_MAX_HOPS = 5

  update_index('manifestations') { self } # update ManifestationsIndex when entity is updated
  update_index('manifestations_autocomplete') { self } # update ManifestationsAutocompleteIndex when entity is updated

  # The Manifestation a request for this (soft-deleted) one should land on: the first live
  # Manifestation along the soft_redirect chain, or nil if there is none within SOFT_REDIRECT_MAX_HOPS.
  def soft_redirect_destination
    seen = [id]
    current = soft_redirect_target
    SOFT_REDIRECT_MAX_HOPS.times do
      return nil if current.nil? || seen.include?(current.id)
      return current unless current.deprecated?

      seen << current.id
      current = current.soft_redirect_target
    end
    nil
  end

  def involved_authorities
    (expression.involved_authorities + expression.work.involved_authorities).uniq
  end

  def involved_authorities_by_role(role)
    (expression.involved_authorities_by_role(role) + expression.work.involved_authorities_by_role(role)).uniq
                                                                                                        .sort_by(&:name)
  end

  def update_sort_title
    return if changed.include?('sort_title')

    self.sort_title = title.strip_nikkud.tr('[]()*"\'', '').tr('-־', ' ').strip
    self.sort_title = ::Regexp.last_match.post_match if sort_title =~ /^\d+\. /
  end

  def update_alternate_titles
    existingstr = alternate_titles || ''
    existing = existingstr.split(';').map(&:strip)
    newforms = AlternateHebrewForms.call(title)
    combined = (existing + newforms).uniq
    self.alternate_titles = combined.join('; ')
  end

  def genre
    expression.work.genre
  end

  def like_count
    return likers.count
  end

  def video_count
    return external_links.status_approved.linktype_youtube.count
  end

  # this will return the downloadable entity for the Manifestation *if* it is fresh
  def fresh_downloadable_for(doctype)
    dl = downloadables.where(doctype: doctype).first
    return nil if dl.nil?
    return nil unless dl.stored_file.attached? # invalid downloadable without file
    return nil if dl.updated_at < updated_at # needs to be re-generated

    return dl
  end

  def long?
    markdown.length > LONG_LENGTH
  end

  def not_short?
    markdown.length > SHORT_LENGTH
  end

  def heading_lines
    if cached_heading_lines.nil?
      recalc_heading_lines!
    end
    cached_heading_lines.split('|').map(&:to_i)
  end

  def chapters?
    return false if cached_heading_lines.blank? || cached_heading_lines[1..5].index('|').nil?

    return true
  end

  def recalc_heading_lines
    lines = markdown.lines
    temp_heading_lines = []
    lines.each_index { |i| temp_heading_lines << i if lines[i][0..1] == '##' && lines[i][2] != '#' }
    self.cached_heading_lines = temp_heading_lines.join('|')
  end

  def recalc_heading_lines!
    recalc_heading_lines
    save!
  end

  def approved_tags
    taggings.to_a.select { |t| t.approved? && t.tag.approved? }.map(&:tag)
  end

  def as_prose?
    # TODO: implement more generically
    return %w(poetry drama).exclude?(expression.work.genre)
  end

  def safe_filename
    # Use manifestation id as a filename to prevent issues with long filename described here
    # https://github.com/abartov/bybeconv/issues/101#issuecomment-1002994205
    id.to_s
  end

  def to_plaintext
    return html2txt(MultiMarkdown.new(markdown).to_html.force_encoding('UTF-8').gsub(%r{<figcaption>.*?</figcaption>}, '')).gsub("\n\n\n", "\n\n").gsub(
      "\n\n\n", "\n\n"
    )
  end

  # return containing collections of collection_type volume or periodical_issue
  def volumes
    ret = []
    containers = collection_items.map(&:collection)
    containers.each do |c|
      if %w(volume periodical_issue).include?(c.collection_type)
        ret << c
      else
        pc = c.parent_volume_or_isssue
        ret << pc unless pc.nil?
      end
    end
    return ret.flatten
  end

  # The collection this manifestation is the only item of, if there is one.
  #
  # A one-text volume simply *is* that text, so what the lexicon says about the book (see
  # Collection#lex_citations) belongs on the text's own page too. A volume holding several texts is
  # not any one of them, and its citations stay on the collection page.
  def sole_containing_collection
    collection_items.includes(collection: :collection_items).map(&:collection).compact
                    .find { |collection| collection.collection_items.size == 1 }
  end

  # Check if manifestation is contained in any collection of type 'volume',
  # directly or through any parent collection in the tree
  def in_volume?
    collection_items.each do |ci|
      next if ci.collection.nil?

      # Check current collection and traverse up parent tree
      stack = [ci.collection]
      visited = Set.new

      while stack.any?
        current = stack.pop
        next if current.nil? || visited.include?(current.id)

        visited.add(current.id)
        return true if current.volume?

        # Add parent collections to stack
        current.parent_collections.each { |pc| stack << pc }
      end
    end
    false
  end

  # Check if manifestation is contained in any collection of type 'periodical_issue',
  # directly or through any parent collection in the tree
  def in_periodical?
    collection_items.each do |ci|
      next if ci.collection.nil?

      # Check current collection and traverse up parent tree
      stack = [ci.collection]
      visited = Set.new

      while stack.any?
        current = stack.pop
        next if current.nil? || visited.include?(current.id)

        visited.add(current.id)
        return true if current.periodical_issue?

        # Add parent collections to stack
        current.parent_collections.each { |pc| stack << pc }
      end
    end
    false
  end

  # return publisher_site link from this manifestation or from any containing collection
  def publisher_link
    link = external_links.detect(&:linktype_publisher_site?)
    return link if link.present?

    # check containing collections for a publisher link
    collection_items.each do |ci|
      next if ci.collection.blank?

      link = ci.collection.publisher_link
      return link if link.present?
    end

    return nil
  end

  def to_html
    if published?
      MarkdownToHtml.call(markdown)
    else
      I18n.t(:not_public_yet)
    end
  end

  def title_and_authors
    return title + ' / ' + author_string
  end

  def title_and_authors_html
    ret = "<h1>#{title}</h1> <h2>#{I18n.t(:by)} #{authors_string}</h2> "
    if expression.translation?
      ret += "<h2>#{I18n.t(:translated_from)}#{textify_lang(expression.work.orig_lang)} #{I18n.t(:by)} #{translators_string}</h2>"
    end
    return ret
  end

  def manual_delete
    collection_items.destroy_all # this will remove the manifestation from all collections
    destroy!
    expression.involved_authorities.each(&:destroy!)
    w = expression.work
    expression.destroy!
    w.involved_authorities.each(&:destroy!)
    w.destroy!
  end

  def snippet_paragraphs(p_count)
    return MultiMarkdown.new(markdown.lines[0..p_count].join("\n")).to_html.force_encoding('UTF-8').gsub(%r{<h1.*?</h1>}, '').gsub(%r{<figcaption>.*?</figcaption>}, '') # remove MMD's automatic figcaptions, and the initial title
    # stripping tags -- return ActionController::Base.helpers.strip_tags(MultiMarkdown.new(markdown.lines[0..p_count].join("\n")).to_html.force_encoding('UTF-8').gsub(/<h1.*?<\/h1>/,'').gsub(/<figcaption>.*?<\/figcaption>/,'')) # remove MMD's automatic figcaptions, and the initial title
  end

  # Excerpt of the text for a works list's summaries view: the first `line_count`
  # lines of actual prose/verse. Headings are dropped rather than merely skipped
  # over, because a work commonly opens with its title and/or first chapter
  # heading ("## א"), which on its own makes for a useless snippet.
  def snippet_html(line_count)
    lines = markdown.to_s.lines.grep_v(/\A\s*#/).drop_while(&:blank?)
    MultiMarkdown.new(lines.first(line_count).join)
                 .to_html
                 .force_encoding('UTF-8')
                 .gsub(%r{<h\d[^>]*>.*?</h\d>}m, '') # any heading MMD still inferred (e.g. underlined)
                 .gsub(%r{<figcaption>.*?</figcaption>}, '') # MMD's automatic figcaptions
  end

  def authors_string
    return I18n.t(:nil) if expression.work.authors.empty?

    return expression.work.authors.map(&:name).join(', ')
  end

  def first_hebrew_letter
    ret = '*'
    title.each_char { |ch| return ch if title.is_hebrew_codepoint_utf8(ch.codepoints[0]) }
    return ret
  end

  def authors
    return expression.work.authors
  end

  def author_gender
    authors.map { |authority| authority&.person&.gender }.compact.uniq
  end

  def translator_gender
    translators.map { |authority| authority&.person&.gender }.compact.uniq
  end

  def translators
    return expression.translators
  end

  def editors
    return []
  end

  def author_and_translator_ids
    au = authors
    au = [] if au.nil?
    tra = translators
    tra = [] if tra.nil?
    ret = au.pluck(:id) + tra.pluck(:id)
    return ret.uniq
  end

  def translators_string
    return I18n.t(:nil) if expression.translators.empty?

    return expression.translators.map(&:name).join(', ')
  end

  def author_string
    Rails.cache.fetch("m_#{id}_author_string", expires_in: 24.hours) do
      author_string!
    end
  end

  def author_string!
    return I18n.t(:nil) if expression.work.authors.empty?

    ret = expression.work.authors.map(&:name).join(', ')
    if expression.translation
      ret += if translators.empty?
               ' / ' + I18n.t(:unknown)
             else
               ' / ' + translators.map(&:name).join(', ')
             end
    end
    ret # TODO: be less naive
  end

  def legacy_htmlfile
    hh = HtmlFile.joins(:manifestations).where(manifestations: { id: id })
    return nil if hh.empty?

    return hh[0]
  end

  def markdown_with_metadata
    metadata = "Title: #{title}  \nAuthor: #{author_string}  \n\n"
    return metadata + markdown
  end

  # The count is cached in the word_count column, because works lists show it for a whole
  # screenful of works at a time. Roughly okay, despite the markdown artifacts.
  def recalc_word_count
    self.word_count = markdown.to_s.split.length
  end

  def recalc_cached_people
    # pp = []
    # expression.persons.each {|p| pp << p unless pp.include?(p) }
    # expression.work.persons.each {|p| pp << p unless pp.include?(p) }
    # self.cached_people = pp.map{|p| "#{p.name} #{p.other_designation}"}.join('; ') # ZZZ
    self.cached_people = author_string!
    # self.cached_people_ids = pp.map{|x| x.id}.join() # this doesn't actually make sense; a normalized query would be way faster
  end

  def recalc_cached_people!
    recalc_cached_people
    save!
  end

  def recalc_responsibility_statement
    self.responsibility_statement = author_string!
  end

  def recalc_responsibility_statement!
    recalc_responsibility_statement
    save!
  end

  # TODO: calculate this by month
  def self.popular_works_by_genre(genre, xlat)
    if xlat
      Rails.cache.fetch("m_pop_xlat_in_#{genre}", expires_in: 24.hours) do # memoize
        Manifestation.all_published.joins(expression: :work).includes(:expression).where(works: { genre: genre }).where('works.orig_lang != expressions.language').order(impressions_count: :desc).limit(10).map do |m|
          { id: m.id, title: m.title, author: m.author_string }
        end
      end
    else
      Rails.cache.fetch("m_pop_in_#{genre}", expires_in: 24.hours) do # memoize
        Manifestation.all_published.joins(expression: :work).where(works: { genre: genre }).where('works.orig_lang = expressions.language').order(impressions_count: :desc).limit(10).map do |m|
          { id: m.id, title: m.title, author: m.author_string }
        end
      end
    end
  end

  def self.add_publisher_link_to_works(worklist, url, linktext)
    el = ExternalLink.new(linktype: :publisher_site, url: url, description: linktext)
    works = Manifestation.find(worklist)
    works.each do |m|
      newel = el.dup
      m.external_links << newel
      m.save!
    end
  end

  def self.randomize_in_genre_except(except, genre)
    list = []
    i = 0
    loop do
      candidates = Manifestation.all_published.genre(genre).order('RAND()').limit(15)
      candidates.each { |au| list << au unless (except.include? au) || (list.include? au) || (list.length == 10) }
      i += 1
      break if (list.size >= 10) || (i > 10)
    end
    return list
  end

  def self.first_25
    Rails.cache.fetch('m_first_25', expires_in: 24.hours) do
      Manifestation.all_published.order(:sort_title).limit(25)
    end
  end

  def self.most_tagged(count)
    select('manifestations.*')
      .joins(:taggings)
      .where(taggings: { status: Tagging.statuses[:approved] })
      .group('manifestations.id')
      .order(Arel.sql('COUNT(taggings.id) DESC'))
      .limit(count)
  end

  def self.cached_popular_works_by_genre
    Rails.cache.fetch('m_pop_by_genre', expires_in: 24.hours) do
      ret = {}
      get_genres.each do |g|
        ret[g] = {}
        ret[g][:orig] =
          Manifestation.all_published.genre(g).not_translations.distinct.order(impressions_count: :desc).limit(10)
        ret[g][:xlat] =
          Manifestation.all_published.genre(g).translations.distinct.order(impressions_count: :desc).limit(10)
      end
      ret
    end
  end

  def self.cached_count
    Rails.cache.fetch('m_count', expires_in: 24.hours) do
      Manifestation.all_published.count
    end
  end

  def self.cached_work_counts_by_genre
    Rails.cache.fetch('m_count_by_genre', expires_in: 24.hours) do
      counts = Manifestation.published.joins(expression: :work).group(work: :genre).count
      Work::GENRES.index_with { |g| counts[g] || 0 }
    end
  end

  def self.cached_periodical_work_counts_by_genre
    Rails.cache.fetch('m_periodical_count_by_genre', expires_in: 24.hours) do
      # Use ManifestationsIndex to find all manifestations in periodicals
      # This matches the behavior of the search/browse filters which use the same index
      periodical_ids = ManifestationsIndex.query(match: { in_periodical: true })
                                          .pluck(:id)

      counts = Manifestation.published
                            .where(id: periodical_ids)
                            .joins(expression: :work)
                            .group('works.genre')
                            .count

      Work::GENRES.index_with { |g| counts[g] || 0 }
    end
  end

  def self.cached_translated_count
    Rails.cache.fetch('m_xlat_count', expires_in: 24.hours) do
      Manifestation.all_published.translations.count
    end
  end

  def self.cached_pd_count
    Rails.cache.fetch('m_pd_count', expires_in: 24.hours) do
      Manifestation.all_published.pd.count
    end
  end

  def self.newest_works
    published.with_involved_authorities.order(created_at: :desc).limit(10)
  end

  def self.popular_works
    ids = Ahoy::Event.where(name: 'view')
                     .where(item_type: 'Manifestation')
                     .where('time > ?', 1.month.ago)
                     .group(:item_id)
                     .order(Arel.sql('count(*) desc'))
                     .limit(10)
                     .pluck(:item_id)

    return [] if ids.empty?

    # Use where instead of find to handle missing records gracefully
    manifestations = with_involved_authorities.where(id: ids).to_a.index_by(&:id)

    # Return in the original popularity order, skipping missing records
    ids.filter_map { |id| manifestations[id] }
  end

  # Updates the queue of published texts that DetectSuspectedTypos considers worth a human
  # look, one ListItem per text, with a "<type>:<count>;..." tally in `extra`. Run weekly
  # from config/recurring.yml and surfaced by AdminController#suspected_typos.
  #
  # Incremental: only texts modified since the watermark recorded by the previous run are
  # scanned, which after the first pass turns a whole-corpus job into a handful of texts. The
  # first run, and any run passed `full: true`, scans everything - use that after changing a
  # heuristic in DetectSuspectedTypos, since unmodified texts would otherwise keep the verdict
  # the old rules gave them.
  #
  # Within the scanned set the pass is a rebuild, not an append: a text whose typos have been
  # fixed drops off the queue by itself, so editors never clear an entry by hand. The only
  # thing that survives is the editor's verdict, held separately in the
  # SUSPECTED_TYPOS_OKAY_LISTKEY whitelist, whose members are not scanned at all.
  def self.update_suspected_typos_list(full: false)
    # Read before the scan starts, so a text edited while the scan is running is picked up by
    # the next run rather than missed by both. Rounded down to the whole second and then
    # backed off by one more, because MySQL *rounds* fractional seconds into these
    # precision-0 datetime columns while Ruby's iso8601 truncates them: without the margin a
    # text saved during the run can land on a stamp that is not strictly greater than the
    # watermark, and would then be skipped by every later run. The margin costs one second's
    # worth of texts being re-scanned.
    watermark = 1.second.ago.change(usec: 0)
    since = full ? nil : suspected_typos_scanned_through

    scope = suspected_typos_scan_scope(since)
    total = scope.count(:all) # :all, because counting the multi-column custom select is not valid SQL
    # item_id => list_item_id for the whole queue, so each scanned text costs a hash lookup
    # rather than a query.
    queued = ListItem.where(listkey: SUSPECTED_TYPOS_LISTKEY, item_type: name).pluck(:item_id, :id).to_h
    handled = 0
    added = 0

    scope.find_each(batch_size: 100) do |m|
      handled += 1
      Rails.logger.info "update_suspected_typos_list: handled #{handled} of #{total}" if (handled % 500).zero?
      findings = DetectSuspectedTypos.call(m.markdown, m[:work_genre])
      list_item_id = queued[m.id]
      if findings.empty?
        ListItem.where(id: list_item_id).destroy_all if list_item_id
      elsif list_item_id
        ListItem.find(list_item_id).update!(extra: summarize_suspected_typos(findings))
      else
        ListItem.create!(listkey: SUSPECTED_TYPOS_LISTKEY, item_id: m.id, item_type: name,
                         extra: summarize_suspected_typos(findings))
        added += 1
      end
    end

    drop_unreachable_suspected_typos
    record_suspected_typos_watermark(watermark)
    Rails.logger.info "update_suspected_typos_list: scanned #{total}, added #{added} new ListItems"
  end

  # Every text the queue is allowed to hold: published, and not whitelisted by an editor.
  def self.suspected_typos_reachable
    whitelisted = ListItem.where(listkey: SUSPECTED_TYPOS_OKAY_LISTKEY, item_type: name).select(:item_id)
    all_published.where.not(id: whitelisted)
  end

  def self.suspected_typos_scan_scope(since)
    scope = suspected_typos_reachable
            .joins(expression: :work)
            .select('manifestations.id, manifestations.markdown, works.genre as work_genre')
    return scope if since.nil?

    # index_manifestations_on_updated_at makes this the cheap half of the job.
    scope.where(updated_at: since...)
  end

  # Queue entries an incremental scan will never revisit, because the text left the scanned
  # set after it was queued: unpublished, or whitelisted outside the report. Deleted texts
  # take their ListItems with them, through the dependent: :destroy above.
  def self.drop_unreachable_suspected_typos
    ListItem.where(listkey: SUSPECTED_TYPOS_LISTKEY, item_type: name)
            .where.not(item_id: suspected_typos_reachable.select(:id))
            .destroy_all
  end

  # nil when no run has been recorded yet, which makes the next run a full one.
  def self.suspected_typos_scanned_through
    recorded = ListItem.where(listkey: SUSPECTED_TYPOS_LAST_RUN_LISTKEY).order(:id).pick(:extra)
    recorded.presence && Time.zone.parse(recorded)
  end

  # ListItem#item is a required association and this marker belongs to no single record, so
  # it is the one ListItem written without validation.
  def self.record_suspected_typos_watermark(watermark)
    marker = ListItem.where(listkey: SUSPECTED_TYPOS_LAST_RUN_LISTKEY).order(:id).first_or_initialize
    marker.extra = watermark.iso8601
    marker.save!(validate: false)
  end

  # A compact tally that fits the 255-character `extra` column, e.g. 'digit_in_word:3;final_mid_word:1'.
  def self.summarize_suspected_typos(findings)
    findings.group_by { |f| f[:type] }.map { |type, group| "#{type}:#{group.length}" }.join(';')
  end
end
