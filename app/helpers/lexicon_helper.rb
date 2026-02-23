# frozen_string_literal: true

# Helpers for lexicon pages
module LexiconHelper
  def render_citation(lex_citation)
    author_bit = lex_citation.authors.sort_by(&:display_name)
                             .map { |author| render_citation_author(author) }.join(', ')
    raw "#{author_bit}, #{lex_citation.title}, " \
        "<u>#{lex_citation.from_publication}</u>#{', עמ\' ' + lex_citation.pages if lex_citation.pages.present?}"
  end

  def render_citation_author(author)
    if author.person.present?
      "<b>#{link_to(author.display_name, lexicon_entry_path(author.person.entry))}</b>"
    else
      "<b>#{author.display_name}</b>"
    end
  end

  def render_person_work(work)
    result = if work.lex_publication.present?
               link_to(work.lex_publication.title, lexicon_entry_path(work.lex_publication.entry))
             else
               work.title
             end

    result += " (#{work.publication_place} : #{work.publisher}, #{work.publication_date})"
    if work.comment.present?
      result += " < #{work.comment} >"
    end
    raw result
  end

  def citations_subject_header(subject_title)
    if subject_title.present?
      t('lexicon.citations.header.subject_line', subject: subject_title)
    else
      t('lexicon.citations.header.general')
    end
  end

  def grouped_and_ordered_citations(lex_person)
    person_works = lex_person.works.index_by(&:title)
    # we preload data required for citations rendering
    grouped_citations = lex_person.citations.preload(authors: { person: :entry })
                                  .group_by(&:subject_title).sort_by do |subject_title, _entries|
      work = person_works[subject_title] if subject_title.present?
      # sort General (empty subject) first, then titles associated with Person Works, then custom titles
      ord = if subject_title.nil?
              0 # general citations without subject first
            elsif work.present?
              1 # then citations associated with existing works
            else
              2 # then citations with manually entered subject
            end
      [
        ord,
        work&.seqno || 1_000_000,
        subject_title || '' # if we use custom subject-title not linked to work, sort them by subject_title
      ]
    end

    grouped_citations = grouped_citations.to_h

    # sort all citations inside subject_title groups by seqno
    grouped_citations.each_value do |entries|
      entries.sort_by! { |citation| [citation.seqno, citation.id] }
    end

    grouped_citations
  end


end
