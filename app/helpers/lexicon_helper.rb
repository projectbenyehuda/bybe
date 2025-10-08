# frozen_string_literal: true

# Helpers for lexicon pages
module LexiconHelper
  def render_citation(lex_citation)
    if lex_citation.status_raw?
      raw lex_citation.raw
    else
      raw "#{lex_citation.authors} #{lex_citation.title} #{lex_citation.pages}"
    end
  end
end
