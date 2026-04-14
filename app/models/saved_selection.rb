# frozen_string_literal: true

# Stores a named, reusable set of records (Manifestations and/or Collections)
# for use with the mass update tool. Selections expire after delete_after date.
class SavedSelection < ApplicationRecord
  belongs_to :user
  has_many :saved_selection_items, dependent: :destroy

  validates :name, presence: true
  validates :delete_after, presence: true

  before_validation :set_default_delete_after, on: :create

  scope :active, -> { where(delete_after: Time.zone.today..) }
  scope :visible_to, ->(user) { active.where(user: user).or(active.where(shared: true)) }

  private

  def set_default_delete_after
    self.delete_after ||= 90.days.from_now.to_date
  end
end
