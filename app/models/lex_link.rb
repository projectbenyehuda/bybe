# frozen_string_literal: true

# Link related to lexicon entry
class LexLink < ApplicationRecord
  belongs_to :item, polymorphic: true, inverse_of: :links

  validates :url, presence: true
end
