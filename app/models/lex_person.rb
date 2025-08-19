# frozen_string_literal: true

# Person from Lexicon
class LexPerson < ApplicationRecord
  include LifePeriod

  has_one :entry, as: :lex_item, class_name: 'LexEntry', dependent: :destroy
  has_many :lex_links, as: :item, dependent: :destroy
  belongs_to :authority, optional: true

  accepts_nested_attributes_for :entry, update_only: true

  def intellectual_property
    copyrighted? ? 'copyrighted' : 'public_domain'
  end
end
