# frozen_string_literal: true

# Helpers for lexicon pages
module LexiconHelper
  def render_citation(lex_citation)
    author_bit = lex_citation.authors.sort_by(&:display_name)
                             .map { |author| render_citation_author(author) }.join(', ')

    links = lex_citation.text_links
    title_bit = if lex_citation.link.blank?
                  # text_links are not applied when the whole title is already a link (no nested anchors)
                  apply_text_links(lex_citation.title, links)
                else
                  link_to(lex_citation.title, lex_citation.link, target: '_blank', rel: 'noopener noreferrer')
                end
    publication_bit = apply_text_links(lex_citation.from_publication, links)

    raw "#{author_bit}, #{title_bit}, " \
        "<u>#{publication_bit}</u>#{', עמ\' ' + lex_citation.pages if lex_citation.pages.present?}"
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

  # Renders a work title, applying hyperlinks from title_links if present.
  # When the work has a BY Collection or a lex_publication, the whole title links there and
  # title_links are not applied (nested anchors are invalid HTML). A Collection takes
  # precedence: it is the actual text on the main site.
  # Returns a plain String (possibly containing HTML) so that render_person_work can
  # safely concatenate further HTML before calling raw() at the end.
  def render_person_work_title(work)
    if work.collection.present?
      link_to(work.title, collection_path(work.collection))
    elsif work.lex_publication.present?
      entry = work.lex_publication.entry
      link_to(entry.title, lexicon_entry_path(entry))
    elsif work.title_links.is_a?(Array) && work.title_links.present?
      apply_text_links(work.title, work.title_links)
    else
      work.title
    end
  end

  def render_person_work(work)
    parts = [
      render_person_work_title(work),
      "(#{work.publication_place} : #{work.publisher}, #{work.publication_date})"
    ]

    parts += work.linked_people
                 .sort_by(&:sort_value)
                 .map { |person| angle_bracketed(render_linked_person(person)) }

    parts += work.comment.to_s.split("\n").compact_blank
                 .map { |comment| angle_bracketed(render_person_work_comment(comment, work.comment_links)) }

    # every part is separated from the next by exactly one space, so the brackets below never
    # need one of their own
    raw parts.join(' ')
  end

  # Wraps content in angled brackets, with NO space between a bracket and the content it
  # encloses (the space belongs outside the brackets — see render_person_work).
  # The brackets are emitted as entities so that content beginning or ending with a link can't
  # produce a "<<a href=" / "</a>>" sequence for the HTML parser to trip over.
  def angle_bracketed(content)
    "&lt;#{content.to_s.strip}&gt;"
  end

  # Renders a work comment, hyperlinking any text listed in comment_links.
  def render_person_work_comment(comment, comment_links)
    apply_text_links(comment, comment_links)
  end

  # Hyperlinks occurrences of each link pair's text within the given plain text.
  # A link pair is either { 'text' => ..., 'entry_id' => ... } (a lexicon entry) or
  # { 'text' => ..., 'url' => ... } (an arbitrary URL). Pairs whose text does not occur in
  # the given text are simply ignored, which is what lets one set of pairs be applied to
  # several fields of the same record (e.g. a citation's title and from_publication).
  # Returns an HTML-safe String with the text escaped and matched occurrences replaced by links.
  def apply_text_links(text, links)
    links = Array(links)
    html = ERB::Util.html_escape(text.to_s)
    return html.html_safe if links.empty?

    entries = text_link_entries(links)
    links.each do |link|
      link_text = link['text']
      next if link_text.blank?

      anchor = text_link_anchor(link, entries)
      next if anchor.nil?

      escaped_text = ERB::Util.html_escape(link_text)
      # Block form of sub avoids interpreting & or \1 in the replacement string
      html = html.sub(escaped_text) { anchor }
    end
    html.html_safe
  end

  # Loads the LexEntries referenced by a set of link pairs in one query, so that a list of pairs
  # can be rendered without an N+1 over their entry_ids.
  def text_link_entries(links)
    LexEntry.where(id: Array(links).filter_map { |link| link['entry_id'] }).index_by(&:id)
  end

  # Builds the anchor for a single link pair, or nil when it points nowhere (blank url, or an
  # entry_id whose LexEntry has since been deleted). Callers rendering several pairs should build
  # `entries` once with text_link_entries and pass it in.
  def text_link_anchor(link, entries = nil)
    if link['entry_id'].present?
      entry = entries ? entries[link['entry_id']] : LexEntry.find_by(id: link['entry_id'])
      entry && link_to(link['text'], lexicon_entry_path(entry))
    elsif link['url'].present?
      link_to(link['text'], link['url'], target: '_blank', rel: 'noopener noreferrer')
    end
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

  # Many legacy subjects are already phrased as 'על "שם היצירה"', so wrapping them in the
  # subject_line template would yield a doubled 'על ״על "שם היצירה"״'. Such subjects are shown
  # as-is. The quote is required: genuine work titles that merely begin with the word על
  # (e.g. 'על חכמות דרכים : שירים') still get the wrapper.
  ALREADY_ABOUT_SUBJECT_RE = /\Aעל\s+["״“”]/

  def citations_subject_header(subject_title)
    if subject_title.blank?
      t('lexicon.citations.header.general')
    elsif subject_title.match?(ALREADY_ABOUT_SUBJECT_RE)
      subject_title
    else
      t('lexicon.citations.header.subject_line', subject: subject_title)
    end
  end

  EXTERNAL_IDENTIFIER_URLS = {
    'lc' => ->(id) { "https://id.loc.gov/authorities/#{id}" },
    'viaf' => ->(id) { "https://viaf.org/viaf/#{id}" },
    'nli' => ->(id) { "https://www.nli.org.il/he/authorities/#{id}" },
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

  # Which of an entry's lexicon sections actually have content, in display order.
  #
  # A section with nothing in it is omitted entirely rather than shown as an empty card, so the
  # cards and the navbar lines that scroll to them must agree on what "empty" means. Four views
  # share this: the entry page and its navbar (lexicon/entries/_show_person, _show_publication,
  # _navbar) and the Authority TOC and its navbar (authors/_generated_toc, shared/_newtoc_navbar).
  #
  # Insertion order is the display order, so `.keys.first` is the topmost visible section --
  # which is what the navbars mark active and scroll to by default.
  def lexicon_sections_present(lex_item, lex_entry)
    if lex_item.is_a?(LexPerson)
      { biography: lex_item.bio.present?,
        works: lex_item.works.any?,
        about: lex_item.citations.any?,
        links: lex_item.links.any?,
        authority_control: render_external_identifiers(lex_entry.external_identifiers).present? }
    else
      { description: lex_item.description.present?,
        toc: lex_item.toc.present?,
        links: lex_item.links.any? }
    end.select { |_section, present| present }
  end

  # Attributes for one link in the lexicon entry navbar. Sections are omitted when empty, so
  # which one starts out active depends on the entry: it is whichever is shown first.
  def lexicon_nav_link_attributes(section, first_section)
    active = section == first_section
    { class: ('active' if active), 'aria-selected' => active.to_s, href: '#' }
  end

  # Returns bio text with any <img> tag whose src contains the profile image filename removed.
  # Call this before passing bio to MarkdownToHtml to avoid showing the profile image twice.
  def bio_for_display(bio_text, lex_entry)
    profile_image = lex_entry.profile_image
    return bio_text if bio_text.blank? || profile_image.blank?

    filename = profile_image.filename.to_s
    bio_text.gsub(%r{<img\b[^>]*src=["'][^"']*#{Regexp.escape(filename)}[^"']*["'][^>]*/?>}i, '')
  end

  # Indexes the entry's attachments by the two keys a citation can claim a file by: its
  # download_path, and its blob id. Building this once lets a citation be matched with hash
  # lookups; it also keeps download_path — route generation plus URI unescaping — to one call per
  # attachment rather than one per (attachment, citation) pair.
  def attachment_index(lex_entry)
    attachments = lex_entry.attachments.to_a
    {
      by_path: attachments.group_by { |attachment| lex_entry.download_path(attachment.filename.to_s) },
      by_blob: attachments.index_by(&:blob_id)
    }
  end

  # Returns the entry's attachments identified as belonging to the given citation: the file
  # attached as its backup_file, plus any file its link or backup_url points at. Callers matching
  # many citations against one entry should build `index` once and pass it in, and should preload
  # `backup_file_attachment: :blob`.
  def citation_attachments(lex_entry, citation, index = attachment_index(lex_entry))
    # links may carry an anchor (e.g. /files/lex/1/foo.pdf#page=3), which download_path never has
    cited_paths = [citation.link, citation.backup_url].compact_blank.map { |url| url.split('#').first }

    matches = cited_paths.flat_map { |path| index[:by_path][path] || [] }
    matches << index[:by_blob][citation.backup_file.blob.id] if citation.backup_file.attached?
    matches.compact.uniq
  end

  # Returns the entry's attachments that are NOT already accounted for by one of the person's
  # citations. The verification workbench lists only these in its attachments section, since a
  # citation-owned file is already visible in the citations section as that citation's
  # link or backup_url.
  def non_citation_attachments(lex_entry, lex_person)
    index = attachment_index(lex_entry)
    cited_ids = lex_person.citations.preload(backup_file_attachment: :blob)
                          .flat_map { |citation| citation_attachments(lex_entry, citation, index) }
                          .to_set(&:id)

    lex_entry.attachments.reject { |attachment| cited_ids.include?(attachment.id) }
  end

  # Migration problems we detect ourselves, stored on LexFile#error_message as I18n keys.
  MIGRATION_WARNING_KEYS = [Lexicon::FlagUnmigratedCitations::MESSAGE_KEY].freeze

  # Renders the migration messages recorded on a LexFile. Most of them are exception messages,
  # stored verbatim in whatever language the exception came in; the warnings we raise ourselves
  # are stored as I18n keys instead, so that they display in the editor's own locale rather than
  # the locale the background job happened to run under.
  # Exception messages routinely quote the source file, so every line is escaped: the queue must
  # not render markup that came out of a legacy PHP file.
  def lex_file_error(lex_file)
    lines = lex_file.error_message.to_s.split("\n").map do |line|
      MIGRATION_WARNING_KEYS.include?(line) ? t("lexicon.files.migration_warnings.#{line}") : line
    end

    safe_join(lines, tag.br)
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
