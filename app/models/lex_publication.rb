# frozen_string_literal: true

class LexPublication < ApplicationRecord
  has_one :entry, as: :lex_item, class_name: 'LexEntry', dependent: :destroy

  accepts_nested_attributes_for :entry, update_only: true
end
