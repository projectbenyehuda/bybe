# Anthology is a User-managed collection of texts. Each user can create own anthologies
class Anthology < ApplicationRecord
  include TrackingEvents

  belongs_to :user
  has_many :texts, class_name: 'AnthologyText', dependent: :destroy
  has_many :downloadables, as: :object, dependent: :destroy
  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings, class_name: 'Tag'
  enum :access, { priv: 0, unlisted: 1, pub: 2 }
  validates :title, presence: true, uniqueness: { scope: :user_id }
  scope :publicly_accessible, -> { where(access: %i(unlisted pub)) }
  scope :public_anthology, -> { where(access: :pub) }

  # this will return the downloadable entity for the Anthology *if* it is fresh
  def fresh_downloadable_for(doctype)
    dl = downloadables.where(doctype: doctype).first
    return nil if dl.nil?
    return nil unless dl.stored_file.attached? # invalid downloadable without file
    return nil if dl.updated_at < updated_at # needs to be re-generated

    # also ensure none of the *included* texts is fresher than the saved downloadable
    texts.where.not(manifestation_id: nil).each do |at|
      return nil if dl.updated_at < at.manifestation.updated_at
    end
    return dl
  end

  def page_count(force_update = false)
    if cached_page_count.nil? or updated_at < 30.days.ago or force_update
      count = 0
      texts.each do |at|
        count += at.page_count
      end
      self.cached_page_count = count
      save
    end
    return cached_page_count
  end

  def accessible?(user)
    return true if pub? or unlisted?
    return true if user == self.user

    return false
  end

  def ordered_texts
    ret = []
    unless texts.empty?
      seq = sequence.split(';')
      seq.each do |id|
        ret << texts.select { |x| x.id == id.to_i }.first
      rescue StandardError
      end
    end
    return ret
  end

  def update_sequence(text_id, old, new)
    seq = sequence.split(';')
    if old < new
      seq.insert(new + 1, text_id)
      seq.delete_at(old)
    else
      seq.delete_at(old)
      seq.insert(new, text_id)
    end
    self.sequence = seq.join(';')
    save!
  end

  def append_to_sequence(text_id)
    if sequence.nil? or sequence.empty?
      self.sequence = ''
    else
      self.sequence += ';'
    end
    self.sequence += text_id.to_s
    save!
    page_count(true) # force update
  end

  def remove_from_sequence(text_id)
    return if self.sequence.nil? or self.sequence.empty?

    seq = self.sequence.split(';')
    seq.delete(text_id)
    self.sequence = seq.join(';')
    save!
  end
end
