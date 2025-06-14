class LexEntry < ApplicationRecord
  has_one :lex_file
  belongs_to :lex_item, polymorphic: true # this can be LexPerson or LexPublication (or...?)
  enum status: { raw: 0, migrated: 1, manual: 2, deprecated: 3 } # raw = not done migrating; migrated = should no longer be served from static PHP
end
