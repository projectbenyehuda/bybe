# frozen_string_literal: true

# Lexicon entry about person
class LexPeopleItem < ApplicationRecord
  belongs_to :lex_person
  belongs_to :item, polymorphic: true
end
