# frozen_string_literal: true

# Person from Lexicon
class LexPerson < ApplicationRecord
  has_one :entry, as: :lex_item, class_name: 'LexEntry', dependent: :destroy
  has_many :lex_links, as: :item, dependent: :destroy
  belongs_to :person, optional: true

  accepts_nested_attributes_for :entry, update_only: true
end
