# frozen_string_literal: true

# Person from Lexicon
class LexPerson < ApplicationRecord
  include LifePeriod

  update_index('lex_people_autocomplete') { self }

  enum :gender, { male: 0, female: 1, other: 2, unknown: 3 }

  has_many :citations, inverse_of: :person, class_name: 'LexCitation', dependent: :destroy
  has_one :entry, as: :lex_item, class_name: 'LexEntry', dependent: :destroy
  has_many :links, as: :item, dependent: :destroy, class_name: 'LexLink', inverse_of: :item
  has_many :citation_authors, class_name: 'LexCitationAuthor', dependent: :nullify

  belongs_to :authority, optional: true # link to an Authority record representing this person in BYP

  accepts_nested_attributes_for :entry, update_only: true

  def intellectual_property
    copyrighted? ? 'copyrighted' : 'public_domain'
  end

  def gender_letter
    female? ? 'ה' : 'ו'
  end
end
