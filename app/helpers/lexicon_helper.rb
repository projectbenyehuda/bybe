# frozen_string_literal: true

# Helpers for lexicon pages
module LexiconHelper
  def lexicon_item_path(lex_item)
    if lex_item.is_a?(LexPerson)
      return lexicon_person_path(lex_item)
    elsif lex_item.is_a?(LexPublication)
      return lexicon_publication_path(lex_item)
    end
  end
end
