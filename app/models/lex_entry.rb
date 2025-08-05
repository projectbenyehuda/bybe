# frozen_string_literal: true

# Lexicon Entry (Person, Publication, etc.)
class LexEntry < ApplicationRecord
  has_one :lex_file, dependent: :nullify
  belongs_to :lex_item, polymorphic: true # this can be LexPerson or LexPublication (or...?)
  enum :status, {
    raw: 0,       # not done migrating
    migrated: 1,  # should no longer be served from static PHP
    manual: 2,
    deprecated: 3
  }

  validates :title, :sort_title, :status, presence: true

  before_validation :update_sort_title!
end
