class LexText < ApplicationRecord
  belongs_to :lex_publication
  belongs_to :lex_issue
  belongs_to :manifestation
end
