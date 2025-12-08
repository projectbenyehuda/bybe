# frozen_string_literal: true

# Helpers for lexicon pages
module LexiconHelper
  def render_citation(lex_citation)
    if lex_citation.status_raw?
      raw lex_citation.raw
    else
      # link to Authority if lex_person is linked

      author_bit = "<b>#{if lex_citation.person.present?
                           link_to(lex_citation.authors, lexicon_person_path(lex_citation.person))
                         else
                           lex_citation.authors
                         end}</b>"
      raw "#{author_bit}, #{lex_citation.title}, <u>#{lex_citation.from_publication}</u>#{', עמ\' ' + lex_citation.pages if lex_citation.pages.present?}"
    end
  end
end
