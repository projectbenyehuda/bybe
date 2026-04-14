# frozen_string_literal: true

# A single record (Manifestation or Collection) within a SavedSelection.
class SavedSelectionItem < ApplicationRecord
  belongs_to :saved_selection
  belongs_to :item, polymorphic: true

  ALLOWED_ITEM_TYPES = %w(Manifestation Collection).freeze

  validates :item_type, inclusion: { in: ALLOWED_ITEM_TYPES }
end
