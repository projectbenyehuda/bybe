# frozen_string_literal: true

# Helpers for lexicon pages
module LexiconHelper
  def render_citation(lex_citation)
    author_bit = lex_citation.authors.sort_by(&:display_name)
                             .map { |author| render_citation_author(author) }.join(', ')

    title_bit = if lex_citation.link.blank?
                  lex_citation.title
                else
                  link_to(lex_citation.title, lex_citation.link, target: '_blank', rel: 'noopener noreferrer')
                end

    raw "#{author_bit}, #{title_bit}, " \
        "<u>#{lex_citation.from_publication}</u>#{', עמ\' ' + lex_citation.pages if lex_citation.pages.present?}"
  end

  def render_citation_author(author)
    if author.entry.present?
      "<b>#{link_to(author.display_name, lexicon_entry_path(author.entry))}</b>"
    elsif author.link.present?
      "<b>#{link_to(author.display_name, author.link)}</b>"
    else
      "<b>#{author.display_name}</b>"
    end
  end

  def render_linked_person(linked_person)
    name = if linked_person.person_entry.present?
             link_to(linked_person.name, lexicon_entry_path(linked_person.person_entry))
           else
             linked_person.name
           end
    LexLinkedPerson.human_enum_name(:link_type, linked_person.link_type) + ' ' + name
  end

  def render_person_work(work)
    result = if work.lex_publication.present?
               link_to(work.lex_publication.title, lexicon_entry_path(work.lex_publication.entry))
             else
               work.title
             end

    result += " (#{work.publication_place} : #{work.publisher}, #{work.publication_date})"

    result += work.linked_people
                  .sort_by(&:sort_value)
                  .map { |person| "<  #{render_linked_person(person)}  >" }.join(' ')

    if work.comment.present?
      work.comment.split("\n").each do |comment|
        result += " < #{comment} >"
      end
    end
    raw result
  end

  def format_publication_details(work)
    place = work.publication_place.presence
    rest = [work.publisher, work.publication_date].compact_blank.join(', ')
    if place
      rest.present? ? "#{place}: #{rest}" : place
    else
      rest.presence
    end
  end

  def citations_subject_header(subject_title)
    if subject_title.present?
      t('lexicon.citations.header.subject_line', subject: subject_title)
    else
      t('lexicon.citations.header.general')
    end
  end

  EXTERNAL_IDENTIFIER_URLS = {
    'lc' => ->(id) { "https://id.loc.gov/authorities/#{id}" },
    'viaf' => ->(id) { "https://viaf.org/viaf/#{id}" },
    'nli' => ->(id) { "http://uli.nli.org.il/authorities/#{id}" },
    'wikidata' => ->(id) { "https://www.wikidata.org/wiki/#{id}" },
    'openlibrary' => ->(id) { "https://openlibrary.org/authors/#{id}" }
  }.freeze

  EXTERNAL_IDENTIFIER_LABELS = {
    'lc' => 'LC',
    'viaf' => 'VIAF',
    'nli' => 'NLI',
    'wikidata' => 'Wikidata',
    'openlibrary' => 'OpenLibrary'
  }.freeze

  def render_external_identifier_value(key, value)
    url_builder = EXTERNAL_IDENTIFIER_URLS[key]
    return value unless url_builder

    link_to(value, url_builder.call(value), target: '_blank', rel: 'noopener noreferrer')
  end

  def render_external_identifiers(external_identifiers)
    return nil if external_identifiers.blank?

    pairs = external_identifiers.filter_map do |key, id|
      url_builder = EXTERNAL_IDENTIFIER_URLS[key]
      label = EXTERNAL_IDENTIFIER_LABELS[key]
      next unless url_builder && label

      url = url_builder.call(id)
      link = link_to(id, url, target: '_blank', rel: 'noopener noreferrer')
      "#{label} – #{link}"
    end

    raw pairs.join(' | ') if pairs.any?
  end

  # Returns bio text with any <img> tag whose src contains the profile image filename removed.
  # Call this before passing bio to MarkdownToHtml to avoid showing the profile image twice.
  def bio_for_display(bio_text, lex_entry)
    profile_image = lex_entry.profile_image
    return bio_text if bio_text.blank? || profile_image.blank?

    filename = profile_image.filename.to_s
    bio_text.gsub(%r{<img\b[^>]*src=["'][^"']*#{Regexp.escape(filename)}[^"']*["'][^>]*/?>}i, '')
  end

  def grouped_and_ordered_citations(lex_person)
    person_works = lex_person.works.index_by(&:title)
    # we preload data required for citations rendering
    grouped_citations = lex_person.citations.preload(authors: :entry)
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
