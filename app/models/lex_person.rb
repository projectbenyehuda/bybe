# frozen_string_literal: true

# Person from Lexicon
class LexPerson < ApplicationRecord
  include LifePeriod
  include LexEntryItem

  update_index('lex_people_autocomplete') { self }

  enum :gender, { male: 0, female: 1, other: 2, unknown: 3 }

  has_many :citations, inverse_of: :person, class_name: 'LexCitation', dependent: :destroy
  has_many :citation_authors, class_name: 'LexCitationAuthor', dependent: :nullify
  has_many :lex_people_items, dependent: :destroy
  has_many :publications, through: :lex_people_items, source: :item, source_type: 'LexPublication'

  belongs_to :authority, optional: true # link to an Authority record representing this person in BYP

  def intellectual_property
    copyrighted? ? 'copyrighted' : 'public_domain'
  end

  def gender_letter
    female? ? 'ה' : 'ו'
  end
end
