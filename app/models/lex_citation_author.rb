# frozen_string_literal: true

class LexCitationAuthor < ApplicationRecord
  belongs_to :citation, class_name: 'LexCitation', inverse_of: :authors, foreign_key: 'lex_citation_id'
  belongs_to :entry, optional: true, class_name: 'LexEntry', foreign_key: 'lex_entry_id'

  validates :name, presence: true, if: -> { entry.nil? }
  validates :lex_entry_id, uniqueness: { scope: :lex_citation_id }, allow_nil: true
  validates :link, absence: { message: :link_with_entry_error }, if: -> { entry.present? }
  validate :entry_must_be_person, if: -> { entry.present? }

  # Migrated authors carry the legacy surname-first name; manually added ones have only an
  # entry, whose title is given-name first, so it has to be inverted to match.
  def display_name
    name.presence || entry&.surname_first_title
  end

  private

  def entry_must_be_person
    return if entry.nil?

    is_person = entry.lex_item.is_a?(LexPerson) ||
                entry.lex_file&.entrytype_person?

    errors.add(:entry, :not_a_person) unless is_person
  end
end
