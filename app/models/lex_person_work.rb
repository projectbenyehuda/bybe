# frozen_string_literal: true

# Work created by LexPerson. It contains only basic matadata and optional link to LexPublication.
class LexPersonWork < ApplicationRecord
  belongs_to :person, class_name: 'LexPerson', foreign_key: :lex_person_id, inverse_of: :works
  belongs_to :publication, class_name: 'LexPublication', foreign_key: :lex_publication_id, optional: true
  validates :title, :work_type, presence: true

  enum :work_type, { original: 0, translated: 1, edited: 2 }, prefix: true
end
