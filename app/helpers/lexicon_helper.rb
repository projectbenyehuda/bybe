# frozen_string_literal: true

# Helpers for lexicon pages
module LexiconHelper
  def render_citation(lex_citation)
    if lex_citation.status_raw?
      raw lex_citation.raw
    else
      raw "<b>#{lex_citation.authors}</b>, #{lex_citation.title}, <u>#{lex_citation.from_publication}</u>#{', עמ\' ' + lex_citation.pages if lex_citation.pages.present?}"
    end
  end
end
