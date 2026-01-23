# frozen_string_literal: true

class TagName < ApplicationRecord
  MIN_SIMILARITY = 70 # minimum similarity (%) for a tag name to be considered similar to another tag name

  belongs_to :tag, inverse_of: :tag_names
  validates :name, presence: true, uniqueness: true
  scope :approved, -> { joins(:tag).includes(:tag).where(tags: { status: Tag.statuses[:approved] }) }

  def similar_to?(other_name)
    d = DamerauLevenshtein.distance(name, other_name)
    l = [name.length, other_name.length].max.to_f
    idx = ((1 - (d / l)) * 100).round # similarity index as a function of distance and length
    return false unless idx >= MIN_SIMILARITY

    return idx
  end
end
