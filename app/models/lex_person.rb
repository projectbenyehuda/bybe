# frozen_string_literal: true

# Person from Lexicon
class LexPerson < ApplicationRecord
  include LifePeriod

  enum :gender, { male: 0, female: 1, other: 2, unknown: 3 }

  has_many :citations, inverse_of: :person, class_name: 'LexCitation', dependent: :destroy
  has_one :entry, as: :lex_item, class_name: 'LexEntry', dependent: :destroy
  has_many :lex_links, as: :item, dependent: :destroy
  belongs_to :authority, optional: true # link to an Authority record representing this person in BYP

  accepts_nested_attributes_for :entry, update_only: true

  def intellectual_property
    copyrighted? ? 'copyrighted' : 'public_domain'
  end

  def gender_letter
    return gender == 'female' ? 'ה' : 'ו'
  end

  def self.find_or_create_by_authority_id(aid)
    lex_person = LexPerson.find_by(authority_id: aid)
    return lex_person if lex_person

    LexPerson.create!(authority_id: aid) # TODO: figure out if it makes sense to import life years or other data from Authority
  end
end
