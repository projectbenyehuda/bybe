# frozen_string_literal: true

class LexCitationAuthor < ApplicationRecord
  belongs_to :citation, class_name: 'LexCitation', inverse_of: :authors, foreign_key: 'lex_citation_id'
  belongs_to :person, optional: true, class_name: 'LexPerson', foreign_key: 'lex_person_id'

  validates :name, presence: true, if: -> { person.nil? }
  validates :name, absence: true, if: -> { person.present? }
  validates :lex_person_id, uniqueness: { scope: :lex_citation_id }, allow_nil: true

  def display_name
    person&.entry&.title || name
  end
end
