class LexEntry < ApplicationRecord
  has_one :lex_file
  belongs_to :lex_item, polymorphic: true
  # this can be LexPerson or LexPublication (or...?)
  enum status: %i(raw migrated manual deprecated)

end
