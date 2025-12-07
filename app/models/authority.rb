# frozen_string_literal: true

# Authority as in authorship, not as in the monopoly-on-force sense that's the ready association for muggles.
class Authority < ApplicationRecord
  include TrackingEvents

  # NOTE: Wikidata URIs are case-sensitive
  WIKIDATA_URI_PATTERN = %r{\Ahttps://wikidata.org/wiki/Q[0-9]+\z}
  PBY_AUTHORITY_ID = 3358

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

  # features
  has_paper_trail ignore: %i(impressions_count created_at updated_at)

  has_attached_file :profile_image, styles: { full: '720x1040', medium: '360x520', thumb: '180x260', tiny: '90x120' },
                                    default_url: :placeholder_image_url,
                                    storage: :s3,
                                    s3_credentials: 'config/s3.yml',
                                    s3_region: 'us-east-1'

  # validations
  validates :name, :intellectual_property, presence: true
  validates :wikidata_uri, format: WIKIDATA_URI_PATTERN, allow_nil: true
  validates :uncollected_works_collection, uniqueness: true, allow_nil: true
  validate :validate_collection_types
  validate :validate_linked_authority

  validates_attachment_content_type :profile_image, content_type: %r{\Aimage/.*\z}

  before_validation do
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

  after_commit :update_manifestation_responsibility_statements, on: :update, if: :saved_change_to_name?

  def update_manifestation_responsibility_statements
    # Find all manifestations related to this authority through involved_authorities
    # This includes both work-level (authors) and expression-level (translators) authorities
    manifestation_ids = Manifestation
                         .joins("INNER JOIN expressions ON manifestations.expression_id = expressions.id")
                         .joins("LEFT JOIN involved_authorities work_ias ON work_ias.item_id = expressions.work_id AND work_ias.item_type = 'Work'")
                         .joins("LEFT JOIN involved_authorities expr_ias ON expr_ias.item_id = expressions.id AND expr_ias.item_type = 'Expression'")
                         .where("work_ias.authority_id = ? OR expr_ias.authority_id = ?", id, id)
                         .distinct
                         .pluck(:id)

    # Enqueue background job to update responsibility statements in bulk
    UpdateManifestationResponsibilityStatementsJob.perform_async(manifestation_ids) unless manifestation_ids.empty?
  end

  # return all collections of type volume that are associated with this authority
  def volumes
    Collection.joins(:involved_authorities).where(collection_type: 'volume', involved_authorities: { authority_id: id })
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

  def fetch_credits
    return cached_credits if cached_credits.present?

    credits = []
    credits += legacy_credits.lines if legacy_credits.present?
    published_manifestations.each do |m|
      credits += m.credits.lines if m.credits.present?
    end
    credits.map!(&:strip)
    credits.uniq!
    credits.reject! { |c| c == '...' }
    credits.sort!
    self.cached_credits = credits.join("\n")
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
    o = original_works.where('manifestations.created_at > ?', since).limit(maxitems)
    t = translations.where('manifestations.created_at > ?', since).limit(maxitems)
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

  def self.cached_count
    Rails.cache.fetch('au_total_count', expires_in: 12.hours) do
      count
    end
  end

  def self.cached_toc_count
    Rails.cache.fetch('au_toc_count', expires_in: 12.hours) do
      has_toc.count
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
    published_manifestations(:author, :translator).order(created_at: :desc).limit(20)
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
      preload(:person, :corporate_body).find(ids)
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
    self.published_at = Time.zone.now
    published! # finally, set this person to published
  end

  def publish_if_first!
    publish! if awaiting_first?
  end

  protected

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
