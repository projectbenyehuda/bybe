class Expression < ApplicationRecord
  include RecordWithInvolvedAuthorities

  before_save :set_translation
  before_save :norm_dates
  enum :period, {
    ancient: 0,
    medieval: 1,
    enlightenment: 2,
    revival: 3,
    modern: 4
  }

  belongs_to :work, inverse_of: :expressions
  has_many :manifestations, inverse_of: :expression, dependent: :destroy
  has_many :aboutnesses, as: :aboutable, dependent: :destroy
  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings, class_name: 'Tag'
  has_paper_trail # for monitoring crowdsourced inputs

  enum :intellectual_property, {
    public_domain: 0,
    by_permission: 1,
    copyrighted: 2,
    orphan: 3,
    unknown: 100
  }, prefix: true

  # In browse works filters and API we should not show copyrighted works
  PUBLIC_INTELLECTUAL_PROPERTY_TYPES = intellectual_properties.keys - ['copyrighted']

  validates :intellectual_property, presence: true

  def translators
    involved_authorities_by_role(:translator)
  end

  def self.cached_translations_count
    Rails.cache.fetch('e_translations', expires_in: 24.hours) do
      Expression.where(translation: true).count
    end
  end

  # Returns total count of published works by each period
  # @return hash where keys are period names and value is a number of works from the given period
  def self.cached_work_count_by_periods
    Rails.cache.fetch('e_works_by_periods', expires_in: 24.hours) do
      Expression.joins(:manifestations, :work)
               .merge(Manifestation.all_published)
               .where(works: { primary: true })
               .group(:period).count
    end
  end

  protected

  def set_translation
    self.translation = language != work.orig_lang
    return true
  end

  def norm_dates
    nd = normalize_date(date)
    self.normalized_pub_date = nd
    nd2 = normalize_date(first_publication_date)
    self.normalized_first_publication_date = nd2
  end
end
