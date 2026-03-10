# frozen_string_literal: true

class LexCitationAuthor < ApplicationRecord
  belongs_to :citation, class_name: 'LexCitation', inverse_of: :authors, foreign_key: 'lex_citation_id'
  belongs_to :entry, optional: true, class_name: 'LexEntry', foreign_key: 'lex_entry_id'

  validates :name, presence: true, if: -> { entry.nil? }
  validates :name, absence: true, if: -> { entry.present? }
  validates :lex_entry_id, uniqueness: { scope: :lex_citation_id }, allow_nil: true
  validates :link, absence: { message: :link_with_entry_error }, if: -> { entry.present? }
  validate :entry_must_be_person, if: -> { entry.present? }

  def display_name
    entry&.title || name
  end

  private

  def entry_must_be_person
    return if entry.nil?

    is_person = entry.lex_item.is_a?(LexPerson) ||
                entry.lex_file&.entrytype_person?

    errors.add(:entry, :not_a_person) unless is_person
  end
end
