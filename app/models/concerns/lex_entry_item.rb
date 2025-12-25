# frozen_string_literal: true

# Concern for Lexicon entry items contains common code for all top-level Lexicon models
module LexEntryItem
  extend ActiveSupport::Concern

  included do
    has_one :entry, as: :lex_item, class_name: 'LexEntry', dependent: :destroy
    has_many :links, as: :item, dependent: :destroy, class_name: 'LexLink', inverse_of: :item

    accepts_nested_attributes_for :entry, update_only: true
  end
end
