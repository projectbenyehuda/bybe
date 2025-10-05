# frozen_string_literal: true

# Lexicon entry about publication
class LexPublication < ApplicationRecord
  include Lexicon::WithCitations

  has_one :entry, as: :lex_item, class_name: 'LexEntry', dependent: :destroy

  accepts_nested_attributes_for :entry, update_only: true
end
