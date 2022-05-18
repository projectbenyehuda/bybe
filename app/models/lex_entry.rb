class LexEntry < ApplicationRecord
  belongs_to :lex_item, polymorphic: true
  # this can be LexPerson or LexPublication (or...?)
end
