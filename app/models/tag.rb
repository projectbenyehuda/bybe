class Tag < ApplicationRecord
  has_many :taggings, dependent: :destroy
  has_many :tag_names, dependent: :destroy
  # NOTE: the 'name' field in tag is the *preferred*/display name. All tag names are in TagName records (including this main preferred one, so that one can search *only* the TagName records)
  after_create :create_tag_name

  belongs_to :creator, foreign_key: :created_by, class_name: 'User'
  belongs_to :approver, class_name: 'User', optional: true
  enum :status, { pending: 0, approved: 1, rejected: 2, escalated: 3 }
  validates :name, presence: true
  validates :created_by, presence: true
  validates :status, presence: true

  scope :pending, -> { where(status: Tag.statuses[:pending]) }
  scope :approved, -> { where(status: Tag.statuses[:approved]) }
  scope :rejected, -> { where(status: Tag.statuses[:rejected]) }
  scope :with_taggings, -> { where('COALESCE(taggings_count, 0) > 0') }
  scope :by_popularity, -> { order('taggings_count DESC') }
  scope :by_user, ->(user) { where(created_by: user.id) }

  # only use this to search for tags, to ensure aliases are searched as well!
  scope :by_name, ->(name) { joins(:tag_names).where(tag_names: { name: name }) }

  def approve!(approver)
    self.approver = approver
    self.status = Tag.statuses[:approved]
    save
  end

  def reject!(rejecter)
    update(status: Tag.statuses[:rejected], approver_id: rejecter.id)
    taggings.update_all(status: Tagging.statuses[:rejected], approved_by: rejecter.id)
  end

  def escalate!(escalator)
    update(status: Tag.statuses[:escalated], approver_id: escalator.id)
  end

  def unreject!
    update(status: Tag.statuses[:pending])
  end

  def unapprove!
    update(status: Tag.statuses[:pending])
  end

  def delete_taggings
    taggings.destroy_all
  end

  def delete_taggings_by_user(user)
    taggings.where(created_by: user.id).destroy_all
  end

  def approved_taggings
    taggings.where(status: Tagging.statuses[:approved])
  end

  def work_taggings
    taggings.where(taggable_type: 'Work')
  end

  def expression_taggings
    taggings.where(taggable_type: 'Expression')
  end

  def manifestation_taggings
    taggings.where(taggable_type: 'Manifestation')
  end

  def anthology_taggings
    taggings.where(taggable_type: 'Anthology')
  end

  def authority_taggings
    taggings.where(taggable_type: 'Authority')
  end

  def merge_into(tag)
    tag_names.update_all(tag_id: tag.id) # make all this tag's tag_names be aliases of the destination tag
    merge_taggings_into(tag)
    reload # to avoid destroying the taggings we just moved!
    destroy
  end

  def merge_taggings_into(tag)
    taggings.each do |tagging|
      # avoid duplicating taggings post-merge
      if tag.taggings.where(taggable_id: tagging.taggable_id, taggable_type: tagging.taggable_type).exists?
        tagging.destroy
      else
        tagging.update!(tag_id: tag.id)
      end
    end
  end

  def prev_tags_alphabetically(limit = 3)
    TagName.where('name < ?', name).order('name DESC').limit(limit)
  end

  def next_tags_alphabetically(limit = 3)
    TagName.where('name > ?', name).order('name ASC').limit(limit)
  end

  def self.cached_popular_tags
    Rails.cache.fetch('popular_tags', expires_in: 1.hour) do
      Tag.approved.by_popularity.limit(10)
    end
  end

  protected

  def create_tag_name # create a TagName with the preferred name
    TagName.create!(tag_id: id, name: name)
  end
end
