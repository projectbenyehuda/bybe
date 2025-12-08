# frozen_string_literal: true

# Lexicon entry about publication
class LexPublication < ApplicationRecord
  has_one :entry, as: :lex_item, class_name: 'LexEntry', dependent: :destroy

  has_many :citations, as: :item, inverse_of: :item, class_name: 'LexCitation', dependent: :destroy

  accepts_nested_attributes_for :entry, update_only: true
end
