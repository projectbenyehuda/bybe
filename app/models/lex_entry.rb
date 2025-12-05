# frozen_string_literal: true

# Lexicon Entry (Person, Publication, etc.)
class LexEntry < ApplicationRecord
  has_one :lex_file, dependent: :nullify

  # this can be LexPerson or LexPublication (or...?)
  # TODO: make relation mandatory after all PHP files will be migrated
  belongs_to :lex_item, polymorphic: true, optional: true, dependent: :destroy

  enum :status, {
    draft: 0,       # entry created but not ready for public access
    published: 1,   # entry approved for public access
    deprecated: 2,  # entry deprecated (maybe superseded by another entry)
    raw: 101,       # migration not done
    migrating: 102, # async migration in progress
    error: 103      # error during migration
  }, prefix: true

  has_many_attached :attachments # attachments referenced by link or image on the entry page
  has_many :legacy_links, class_name: 'LexLegacyLink', dependent: :destroy, inverse_of: :lex_entry

  validates :title, :sort_title, :status, presence: true

  before_validation :update_sort_title!
end
