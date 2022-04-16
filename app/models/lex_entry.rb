class LexEntry < ApplicationRecord
  belongs_to :lex_person
  belongs_to :lex_publication
end
