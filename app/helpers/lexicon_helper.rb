# frozen_string_literal: true

# Helpers for lexicon pages
module LexiconHelper
  def render_citation(lex_citation)
    if lex_citation.status_raw?
      raw lex_citation.raw
    else
      author_bit = lex_citation.authors.sort_by(&:display_name)
                               .map { |author| render_citation_author(author) }.join(', ')
      raw "#{author_bit}, #{lex_citation.title}, <u>#{lex_citation.from_publication}</u>#{', עמ\' ' + lex_citation.pages if lex_citation.pages.present?}"
    end
  end

  def render_citation_author(author)
    if author.person.present?
      "<b>#{link_to(author.display_name, lexicon_entry_path(author.person.entry))}</b>"
    else
      "<b>#{author.display_name}</b>"
    end
  end

  def render_person_work(work)
    result = if work.publication.present?
              link_to(work.publication.title, lexicon_entry_path(work.publication.entry))
            else
              work.title
            end

    result += " (#{work.publication_place} : #{work.publisher}, #{work.publication_date})"
    if work.comment.present?
      result += " < #{work.comment} >"
    end
    raw result
  end
end
