# frozen_string_literal: true

# Lexicon Entry (Person, Publication, etc.)
class LexEntry < ApplicationRecord
  has_one :lex_file, dependent: :nullify

  # this can be LexPerson or LexPublication (or...?)
  # TODO: make relation mandatory after all PHP files will be migrated
  belongs_to :lex_item, polymorphic: true, optional: true

  enum :status, {
    raw: 0,       # not done migrating
    migrated: 1,  # should no longer be served from static PHP
    manual: 2,
    deprecated: 3
  }

  has_many_attached :images

  validates :title, :sort_title, :status, presence: true

  before_validation :update_sort_title!
end
