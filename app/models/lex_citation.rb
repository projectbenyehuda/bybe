# frozen_string_literal: true

# Citation about lexicon entry

# citations are not first-order entities in the lexicon. They are single-line references to texts about a lexicon
# author or a particular lexicon author's publication.
class LexCitation < ApplicationRecord
  # mandatory relation to the person on whose page this citation appears
  # (it can be about this person, or about one of his/her works)
  belongs_to :person, class_name: 'LexPerson', inverse_of: :citations, foreign_key: :lex_person_id

  # optional item this citation is about (can be null if citation is general about the person)
  belongs_to :item, inverse_of: :citations_about, polymorphic: true, optional: true

  belongs_to :manifestation, optional: true # manifestation representing this citation (if present in BYP)

  # This status column is temporary and should be removed in the future after migration from PHP will be completed
  enum :status,
       {
         raw: 0, # markup copied from PHP file (need to be parsed and splitted into separate columns)
         approved: 1, # markup parsed and stored in separate columns
         manual: 2, # created manually (no raw markup existis)
         ai_parsed: 3 # parsed using AI service
       }, prefix: true

  validates :raw, absence: true, if: :status_manual?
  validates :raw, presence: true, unless: :status_manual?

  validates :title, :authors, presence: true, if: :status_manual?
end
