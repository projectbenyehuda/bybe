# frozen_string_literal: true

class LexCitationAuthor < ApplicationRecord
  belongs_to :citation, class_name: 'LexCitation', inverse_of: :authors, foreign_key: 'lex_citation_id'
  belongs_to :person, optional: true, class_name: 'LexPerson', foreign_key: 'lex_person_id'

  validates :name, presence: true, if: -> { person.nil? }
end