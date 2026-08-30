# frozen_string_literal: true

# Authority as in authorship, not as in the monopoly-on-force sense that's the ready association for muggles.
class Authority < ApplicationRecord
  include TrackingEvents

  # NOTE: Wikidata URIs are case-sensitive
  WIKIDATA_URI_PATTERN = %r{\Ahttps://wikidata.org/wiki/Q[0-9]+\z}
  PBY_AUTHORITY_ID = 3358

  # Collection types that count as a title ('כותר') for the figure the author page advertises.
  # Deliberately excludes `series` and `volume_series` -- those are structural groupings *inside* a
  # title (e.g. the two sub-volumes of a multi-volume work), and the TOC never presents them as
  # titles of their own -- as well as `other` and the system `uncollected` collection.
  COUNTED_COLLECTION_TYPES = %i(volume periodical periodical_issue).freeze

  update_index('authorities') { self } # update AuthoritiesIndex when entity is updated
  update_index('authorities_autocomplete') { self }

  enum :status, {
    published: 0,
    unpublished: 1,
    deprecated: 2,
    awaiting_first: 3
  }

  enum :intellectual_property, {
    public_domain: 0,
    copyrighted: 2,
    orphan: 3,
    permission_for_all: 4,
    permission_for_selected: 5,
    unknown: 100
  }, prefix: true

  # relationships
  belongs_to :toc, optional: true

  has_many :involved_authorities, inverse_of: :authority, dependent: :destroy
  has_many :featured_contents, inverse_of: :authority, dependent: :destroy
  has_many :aboutnesses, as: :aboutable, dependent: :destroy
  has_many :external_links, as: :linkable, dependent: :destroy

  has_many :publications, inverse_of: :authority, dependent: :destroy
  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings, class_name: 'Tag'
  has_many :downloadables, as: :object, dependent: :destroy

  belongs_to :person, optional: true
  belongs_to :corporate_body, optional: true
  belongs_to :uncollected_works_collection, class_name: 'Collection', optional: true
  belongs_to :lexicon_entry, class_name: 'LexEntry', optional: true
  has_one :lex_person, dependent: :nullify

  attr_readonly :person, :corporate_body # Should not be modified after creation

  accepts_nested_attributes_for :person, :corporate_body

  paginates_per 100

  # scopes
  scope :has_toc, -> { where.not(toc_id: nil) }
  scope :no_toc, -> { where(toc_id: nil) }
  scope :has_image, -> { where.not(profile_image_file_name: nil) }
  scope :no_image, -> { where(profile_image_file_name: nil) }
  scope :bib_done, -> { where(bib_done: true) }
  scope :bib_not_done, -> { where('bib_done is null OR bib_done = 0') }
  scope :new_since, ->(since) { where('created_at > ?', since) }
  scope :latest, ->(limit) { order('created_at desc').limit(limit) }
  scope :tagged_with, lambda { |tag_id|
                        joins(:taggings).where(taggings: { tag_id: tag_id, status: Tagging.statuses[:approved] })
                                        .distinct
                      }
  scope :not_pageless, -> { where(pageless: false) }
  scope :featurable, -> { where(do_not_feature: false, pageless: false) }

  # features
  has_paper_trail ignore: %i(impressions_count created_at updated_at)

  has_attached_file :profile_image, styles: { full: '720x1040', medium: '360x520', thumb: '180x260', tiny: '90x120' },
                                    default_url: :placeholder_image_url

  # validations
  validates :name, :intellectual_property, presence: true
  validates :wikidata_uri, format: WIKIDATA_URI_PATTERN, allow_nil: true
  validates :uncollected_works_collection, uniqueness: true, allow_nil: true
  validate :validate_collection_types
  validate :validate_linked_authority

  validates_attachment_content_type :profile_image, content_type: %r{\Aimage/.*\z}

  before_validation do
    # Strip incidental leading/trailing whitespace so it doesn't corrupt alphabetical sorting/display
    self.name = SortedTitle.normalize_whitespace(name) if name.present?

    if wikidata_uri.blank?
      self.wikidata_uri = nil
    else
      uri = wikidata_uri.strip

      # Transform various input formats into canonical Wikidata URL
      # Accept: plain number (123), Q-prefixed (Q123), or full URL
      if uri.match?(/\A\d+\z/)
        # Plain number: "123" → "https://wikidata.org/wiki/Q123"
        self.wikidata_uri = "https://wikidata.org/wiki/Q#{uri}"
      elsif uri.match?(/\AQ\d+\z/i)
        # Q-prefixed: "Q123" or "q123" → "https://wikidata.org/wiki/Q123"
        self.wikidata_uri = "https://wikidata.org/wiki/#{uri.upcase}"
      else
        # URL format: ensure 'Q' is uppercase
        self.wikidata_uri = uri.downcase.gsub('q', 'Q')
      end
    end
  end

  before_save :update_other_designation, if: :name_changed?
  before_save :normalize_sort_name
  # published_at drives the 'upload date' sort on /authors (via AuthoritiesIndex#pby_publication_date),
  # so it must be stamped no matter which code path publishes the authority, not just Authority#publish!
  before_save :stamp_published_at, if: -> { status_changed? && published? }
  before_save :sort_legacy_credits, if: :legacy_credits_changed?
  # editing the manual credits changes the merged list, so the cache must go (cf. Collection)
  before_save :clear_cached_credits, if: :legacy_credits_changed?

  after_commit :update_manifestation_responsibility_statements, on: :update, if: :saved_change_to_name?
  # covers create, update and destroy of a pageless authority, as well as the flag being turned off
  after_commit :bust_pageless_ids_cache, if: -> { pageless? || saved_change_to_pageless? }

  PAGELESS_IDS_CACHE_KEY = 'authority_pageless_ids'

  # IDs of authorities which have no meaningful page of their own (e.g. 'anonymous', 'various authors').
  # The list is tiny and changes very rarely, so it is cached and consulted in memory rather than
  # hitting the DB for every authority mentioned on a page.
  def self.pageless_ids
    Rails.cache.fetch(PAGELESS_IDS_CACHE_KEY, expires_in: 12.hours) do
      where(pageless: true).pluck(:id).to_set
    end
  end

  # @param id [Integer, String] authority id
  def self.pageless_id?(id)
    pageless_ids.include?(id.to_i)
  end

  def bust_pageless_ids_cache
    Rails.cache.delete(PAGELESS_IDS_CACHE_KEY)
  end

  def update_manifestation_responsibility_statements
    # Find all manifestations related to this authority through involved_authorities
    # This includes both work-level (authors) and expression-level (translators) authorities
    manifestation_ids = Manifestation
                        .joins('INNER JOIN expressions ON manifestations.expression_id = expressions.id')
                        .joins("LEFT JOIN involved_authorities work_ias ON work_ias.item_id = expressions.work_id AND work_ias.item_type = 'Work'")
                        .joins("LEFT JOIN involved_authorities expr_ias ON expr_ias.item_id = expressions.id AND expr_ias.item_type = 'Expression'")
                        .where('work_ias.authority_id = ? OR expr_ias.authority_id = ?', id, id)
                        .distinct
                        .pluck(:id)

    # Enqueue background job to update responsibility statements in bulk
    UpdateManifestationResponsibilityStatementsJob.perform_later(manifestation_ids) unless manifestation_ids.empty?
  end

  def update_other_designation
    existingstr = other_designation || ''
    existing = existingstr.split(';').map(&:strip)
    newforms = AlternateHebrewForms.call(name)
    combined = (existing + newforms).uniq
    self.other_designation = combined.join('; ')
  end

  def normalize_sort_name
    return if sort_name.blank?

    # Replace Hebrew maqaf (U+05BE), regular hyphen-minus (U+002D),
    # en dash (U+2013), and em dash (U+2014) with spaces
    self.sort_name = sort_name.gsub(/[\u05BE\u002D\u2013\u2014]/, ' ')
  end

  # Keep the manually-maintained credits alphabetically sorted, so they are easier to edit later
  # (and so they match the order in which credits are displayed).
  def sort_legacy_credits
    return if legacy_credits.blank?

    self.legacy_credits = self.class.sorted_credit_lines(legacy_credits.lines).join("\n")
  end

  def clear_cached_credits
    self.cached_credits = nil
  end

  # return all collections of type volume that are associated with this authority
  def volumes
    Collection.joins(:involved_authorities).where(collection_type: 'volume', involved_authorities: { authority_id: id })
  end

  # #volumes, plus the volumes contained in any volume_series associated with this authority.
  # A multi-volume work often records the authorship once, on the series, leaving the individual
  # volumes with no involved_authorities of their own -- those volumes are this authority's just
  # as much, and are invisible to #volumes because it inner-joins involved_authorities.
  # Only direct members of the series are collected; a series nested inside a series is not walked.
  def volumes_including_series
    series_ids = Collection.joins(:involved_authorities)
                           .where(collection_type: 'volume_series', involved_authorities: { authority_id: id })
                           .select(:id)
    in_series_ids = CollectionItem.where(collection_id: series_ids, item_type: 'Collection').select(:item_id)

    volumes_scope = Collection.where(collection_type: 'volume')
    volumes_scope.where(id: volumes.select(:id)).or(volumes_scope.where(id: in_series_ids))
  end

  # return all manifestation IDs that are included in collections (useful for migrating legacy TOCs)
  def collected_manifestation_ids
    ids = published_manifestations.pluck(:id)
    collected_ids = CollectionItem.joins(:collection).where(item_id: ids,
                                                            item_type: 'Manifestation').where.not(collection: { collection_type: :uncollected }).pluck(:item_id)
  end

  def approved_tags
    approved_taggings.joins(:tag).preload(:tag).where(tag: { status: Tag.statuses[:approved] }).map(&:tag)
  end

  def approved_taggings
    taggings.where(status: Tagging.statuses[:approved])
  end

  def collections
    Collection.where(
      <<~SQL.squish
        exists (
          select 1 from
            involved_authorities ia
          where
            ia.item_id = collections.id
            and ia.item_type = 'Collection'
            and ia.authority_id = #{id}
        )
      SQL
    )
  end

  # Clean up a list of raw credit lines: strip them, drop blanks and placeholders,
  # de-duplicate, and sort alphabetically.
  def self.sorted_credit_lines(lines)
    lines.map(&:strip).reject { |line| line.blank? || line == '...' }.uniq.sort
  end

  def fetch_credits
    # Sorting (and de-duplicating) on read too, so that credits cached before this behavior was
    # introduced, or cached by some other code path, are still presented as one clean list.
    return self.class.sorted_credit_lines(cached_credits.lines).join("\n") if cached_credits.present?

    # manual credits and the ones harvested from the works are merged into a single list, so a
    # volunteer listed in both appears only once
    credits = []
    credits += legacy_credits.lines if legacy_credits.present?
    published_manifestations.each do |m|
      credits += m.credits.lines if m.credits.present?
    end
    self.cached_credits = self.class.sorted_credit_lines(credits).join("\n")
    save!
    return cached_credits
  end

  def invalidate_cached_credits!
    self.cached_credits = nil
    save!
  end

  # @param roles [String / Symbol] optional, if provided will only return Manifestations where authority has
  #   one of the given roles.
  # @return relation representing [Manifestation] objects current authority is involved into.
  def manifestations(*roles)
    rel = involved_authorities
    rel = rel.where(role: roles.to_a) if roles.present?
    ids = rel.pluck(:item_type, :item_id)

    work_ids = ids.select { |type, _id| type == 'Work' }.map(&:last).compact.uniq
    expression_ids = ids.select { |type, _id| type == 'Expression' }.map(&:last).compact.uniq

    Manifestation.joins(:expression)
                 .where('expressions.work_id in (?) or expressions.id in (?)', work_ids, expression_ids)
  end

  # Works like {#manifestaions} method, but returns only published manifestations
  def published_manifestations(*roles)
    manifestations(*roles).all_published
  end

  def any_hebrew_works?
    return true if published_manifestations(:author).joins(expression: :work).exists?(works: { orig_lang: 'he' })

    published_manifestations(:translator).exists?(expressions: { language: 'he' })
  end

  def any_non_hebrew_works?
    return published_manifestations(:author).joins(expression: :work)
                                            .where.not(works: { orig_lang: 'he' }).exists?
  end

  def all_languages
    work_langs = original_works.joins(expression: :work).pluck('works.orig_lang')
    # translation_langs = translations.pluck('works.orig_lang')
    # all_languages = work_langs + translation_langs
    # return all_languages.uniq
    return work_langs.uniq
  end

  def all_genres
    published_manifestations(:author, :translator).joins(expression: :work)
                                                  .select('works.genre')
                                                  .distinct
                                                  .pluck(:genre)
                                                  .sort
  end

  # Returns a hash of genre => manifestation count for each genre where the authority
  # has been involved in at least one manifestation (in any role).
  # Only counts published manifestations.
  # Example: { 'poetry' => 5, 'prose' => 3, 'memoir' => 1 }
  def genre_stats
    # Get work IDs and expression IDs where authority is involved (in any role)
    items = involved_authorities.pluck(:item_type, :item_id)

    work_ids = items.select { |type, _| type == 'Work' }.map(&:last).compact.uniq
    expression_ids = items.select { |type, _| type == 'Expression' }.map(&:last).compact.uniq

    # Return empty hash if authority has no involvements
    return {} if work_ids.empty? && expression_ids.empty?

    # Count published manifestations by genre
    # Use [0] as placeholder when array is empty to avoid SQL syntax errors
    Manifestation
      .all_published
      .joins(expression: :work)
      .where('works.id IN (?) OR expressions.id IN (?)',
             work_ids.presence || [0],
             expression_ids.presence || [0])
      .group('works.genre')
      .count
  end

  # 12h TTL, matching cached_works_count, cached_collections_count and the author page's TOC
  # fragment: the four are rendered side by side, so a longer TTL here let the genre chips drift
  # out of step with the works figure they add up to.
  # NOTE: cache key deliberately versioned. A TTL is stamped on the entry when it is written, so
  # shortening it here would not touch entries already written under the old 24h expiry -- they
  # would keep drifting for up to another 24h after deploy, which is what this change is meant
  # to stop.
  def cached_genre_stats
    Rails.cache.fetch("au_#{id}_genre_stats_v2", expires_in: 12.hours) do
      genre_stats
    end
  end

  def original_works
    published_manifestations(:author)
  end

  def translations
    published_manifestations(:translator)
  end

  def all_works_including_unpublished
    manifestations(:author, :translator).sort_by(&:sort_title)
  end

  # convenience method for polymorphic handling (e.g. Taggable)
  def title
    name
  end

  def works_since(since, maxitems)
    o = original_works.joins(expression: :work)
                      .where(works: { primary: true })
                      .where('manifestations.created_at > ?', since).limit(maxitems)
    t = translations.joins(expression: :work)
                    .where(works: { primary: true })
                    .where('manifestations.created_at > ?', since).limit(maxitems)
    joint = (o + t).uniq # NOTE: both of these are manifestations, not works!
    return joint[0..maxitems - 1] if joint.count > maxitems

    return joint
  end

  def cached_works_count
    Rails.cache.fetch("au_#{id}_work_count", expires_in: 12.hours) do
      published_manifestations.count
    end
  end

  def invalidate_cached_works_count!
    Rails.cache.delete("au_#{id}_work_count")
  end

  # The number of titles we advertise to readers on the author page. It must count what the TOC
  # actually presents as a title, so it is limited to COUNTED_COLLECTION_TYPES: a plain
  # collections.count also counted the `series` sub-collections nested inside a title, which the
  # reader only ever sees as sections *within* a volume card.
  def counted_collections_count
    collections.where(collection_type: COUNTED_COLLECTION_TYPES).count
  end

  # NOTE: cache key deliberately renamed from 'au_<id>_collections_count', so deployments pick up
  # the corrected figure immediately instead of serving the old, inflated one until the TTL expires.
  def cached_collections_count
    Rails.cache.fetch("au_#{id}_counted_collections_count", expires_in: 12.hours) do
      counted_collections_count
    end
  end

  def any_bibs?
    return publications.count > 0
  end

  # this will return the downloadable entity for the Authority *if* it is fresh
  def fresh_downloadable_for(doctype)
    dl = downloadables.where(doctype: doctype).first
    return nil if dl.nil?
    return nil unless dl.stored_file.attached? # invalid downloadable without file
    return nil if dl.updated_at < updated_at # needs to be re-generated if authority was updated

    # also ensure none of the published manifestations is fresher than the saved downloadable
    published_manifestations.find_each do |m|
      return nil if dl.updated_at < m.updated_at
    end

    dl
  end

  # The count of authorities we advertise to readers ('N authors in the project'), and which labels a
  # link to the authorities list -- so it must count exactly what that list shows.
  # NOTE: cache key deliberately renamed from 'au_total_count', so deployments pick up the corrected
  # figure immediately instead of serving the old, inflated one until the TTL expires.
  def self.cached_count
    Rails.cache.fetch('au_published_count', expires_in: 12.hours) do
      published.not_pageless.count
    end
  end

  def all_works_title_sorted
    (original_works + translations).uniq.sort_by(&:sort_title)
  end

  def all_works_by_order(order)
    (original_works.order(order) + translations.order(order)).uniq
  end

  def all_works_by_title(term)
    w = original_works.where('expressions.title like ?', "%#{term}%")
    t = translations.where('expressions.title like ?', "%#{term}%")
    return (w + t).uniq.sort_by(&:sort_title)
  end

  def original_works_by_genre
    hash = published_manifestations(:author).preload(expression: :work)
                                            .group_by { |m| m.expression.work.genre }
    Work::GENRES.index_with { |genre| hash[genre] || [] }
  end

  def translations_by_genre
    hash = published_manifestations(:translator).preload(expression: :work)
                                                .group_by { |m| m.expression.work.genre }
    Work::GENRES.index_with { |genre| hash[genre] || [] }
  end

  def legacy_toc?
    return toc.present? && toc.status == 'deprecated'
  end

  def featured_work
    Rails.cache.fetch("au_#{id}_featured", expires_in: 24.hours) do # memoize
      featured_contents.order(Arel.sql('RAND()')).limit(1)
    end
  end

  def latest_stuff
    published_manifestations(:author, :translator)
      .joins('INNER JOIN works ON works.id = expressions.work_id')
      .where(works: { primary: true })
      .order(created_at: :desc).limit(20)
  end

  def cached_original_works_by_genre
    Rails.cache.fetch("au_#{id}_original_works_by_genre", expires_in: 24.hours) do
      original_works_by_genre
    end
  end

  def cached_translations_by_genre
    Rails.cache.fetch("au_#{id}_translations_by_genre", expires_in: 24.hours) do
      translations_by_genre
    end
  end

  def most_read(limit)
    Rails.cache.fetch("au_#{id}_#{limit}_most_read", expires_in: 24.hours) do
      manifestations(:author).order(impressions_count: :desc).limit(limit).map do |m|
        {
          id: m.id,
          title: m.title,
          author: m.authors_string,
          translation: m.expression.translation,
          genre: m.expression.work.genre
        }
      end
    end
  end

  def cached_popular_tags_used_on_works
    Rails.cache.fetch("au_#{id}_pop_tags", expires_in: 12.hours) do
      popular_tags_used_on_works
    end
  end

  def popular_tags_used_on_works(limit = 10)
    Tag.find(popular_tags_used_on_works_with_count.keys.first(limit))
  end

  def popular_tags_used_on_works_with_count
    mm = (original_works + translations).uniq.pluck(:id)
    Tag.joins(:taggings).where(taggings: { taggable_type: 'Manifestation',
                                           taggable_id: mm }).group('tags.id').order('count_all DESC').count
  end

  def self.popular_authors
    Rails.cache.fetch('m_popular_authors', expires_in: 24.hours) do
      ids = Ahoy::Event.where(name: 'view')
                       .where(item_type: 'Authority')
                       .where('time > ?', 1.month.ago)
                       .group(:item_id)
                       .order(Arel.sql('count(*) desc'))
                       .limit(10)
                       .pluck(:item_id)
      # Filter out non-featurable authorities while preserving order
      featurable_ids_set = featurable.where(id: ids).pluck(:id).to_set
      ordered_featurable_ids = ids.select { |id| featurable_ids_set.include?(id) }
      authorities = preload(:person, :corporate_body).find(ordered_featurable_ids)
      # Sort authorities by the original order
      authorities.sort_by { |a| ordered_featurable_ids.index(a.id) }
    end
  end

  def favorite_of_user
    return false # TODO: implement when user prefs implemented
  end

  def gender
    return nil if person.nil?

    return person.gender
  end

  def gender_letter
    # TODO: refactor this. Added this method to reduce amount of code to be changed during Authorities refactoring
    person.present? ? person.gender_letter : 'ו'
  end

  # Returns an array of sorted names for efficient comparison
  # Each name has its words sorted alphabetically, then the array itself is sorted
  # Example: ["James Smith", "Robert Ames"] => ["James Smith", "Ames Robert"]
  def sorted_comparison_names
    names = [name]
    names += other_designation.split(';').map(&:strip) if other_designation.present?

    # Sort words within each name alphabetically
    sorted_names = names.map do |n|
      n.split(/\s+/).sort.join(' ')
    end

    sorted_names.sort
  end

  # set all person's works to status published
  # be cautious about publishing joint works, because the *other* author(s) or translators may yet be unpublished!
  def publish!
    all_works_including_unpublished.each do |m|
      next if m.published?

      can_publish = true
      m.authors.each { |au| can_publish = false unless au.published? || au == self }
      m.translators.each { |au| can_publish = false unless au.published? || au == self }

      next unless can_publish

      # pretend the works were created just now, so that they appear in whatsnew
      # (NOTE: real creation date can be discovered through papertrail)
      m.created_at = Time.zone.now
      m.published!
    end
    published! # finally, set this person to published (stamp_published_at fires on the transition)
  end

  def publish_if_first!
    publish! if awaiting_first?
  end

  protected

  # Records when the authority became visible on the site. Re-publishing after a spell of being
  # unpublished deliberately re-stamps, matching publish!'s treatment of the works themselves,
  # which are back-dated to now so they resurface in whatsnew. An explicit published_at supplied in
  # the same save wins, so imports and backfills can set a historical date.
  def stamp_published_at
    self.published_at = Time.zone.now unless published_at_changed?
  end

  def placeholder_image_url
    if person.present?
      if person.female?
        '/assets/:style/placeholder_woman.jpg'
      else
        '/assets/:style/placeholder_man.jpg'
      end
    else
      # TODO: add placeholder image for corporate bodies
      '/assets/:style/placeholder_man.jpg'
    end
  end

  def validate_linked_authority
    errors.add(:base, :no_linked_authority) if person.nil? && corporate_body.nil?
    errors.add(:base, :multiple_linked_authorities) if person.present? && corporate_body.present?
  end

  # rubocop:disable Style/GuardClause
  def validate_collection_types
    if uncollected_works_collection.present? && !uncollected_works_collection.uncollected?
      errors.add(:uncollected_works_collection, :wrong_collection_type, expected_type: :uncollected)
    end
  end
  # rubocop:enable Style/GuardClause
end
