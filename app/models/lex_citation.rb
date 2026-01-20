# frozen_string_literal: true

# Citation about lexicon entry

# citations are not first-order entities in the lexicon. They are single-line references to texts about a lexicon
# author or a particular lexicon author's publication.
class LexCitation < ApplicationRecord
  # mandatory relation to the person on whose page this citation appears
  # (it can be about this person, or about one of his/her works)
  belongs_to :person, class_name: 'LexPerson', inverse_of: :citations, foreign_key: :lex_person_id

  # optional LexPersonWork this citation is about (can be null if citation is general about the person)
  belongs_to :person_work,
             class_name: 'LexPersonWork', inverse_of: :citations_about,
             foreign_key: :lex_person_work_id, optional: true

  belongs_to :manifestation, optional: true # manifestation representing this citation (if present in BYP)

  has_many :authors, class_name: 'LexCitationAuthor', inverse_of: :citation, dependent: :destroy

  validates :title, presence: true

  validate :person_work_belongs_to_same_person

  # Subject is a string title of the work this citation is about (if any) and filled during parsing of legacy PHP files.
  # We should replace all subjects with person_work references where possible, and then clear the subject field.
  # After Legacy data migration is done, we can drop subject field entirely.
  validates :subject, absence: true, if: -> { person_work.present? }

  def subject_title
    return person_work&.title || subject
  end

  private

  def person_work_belongs_to_same_person
    return if person_work.nil?
    return if person_work.lex_person_id == lex_person_id

    errors.add(:person_work, :belongs_to_different_person)
  end
end
