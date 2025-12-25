# frozen_string_literal: true

# Lexicon entry about publication
class LexPublication < ApplicationRecord
  include LexEntryItem

  has_many :citations, as: :item, inverse_of: :item, class_name: 'LexCitation', dependent: :destroy
end
