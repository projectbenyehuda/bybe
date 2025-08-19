# frozen_string_literal: true

# Issue of Lexicon Periodical
class LexIssue < ApplicationRecord
  belongs_to :lex_publication
end
