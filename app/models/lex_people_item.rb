class LexPeopleItem < ApplicationRecord
  belongs_to :lex_person
  belongs_to :item, polymorphic: true
end
