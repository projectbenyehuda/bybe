# frozen_string_literal: true

class LexPeopleItem < ApplicationRecord
  belongs_to :lex_person
  belongs_to :item, polymorphic: true
end
