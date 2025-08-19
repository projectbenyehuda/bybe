# frozen_string_literal: true

# Citation about lexicon entry
class LexCitation < ApplicationRecord
  belongs_to :item, polymorphic: true
  belongs_to :manifestation
end
