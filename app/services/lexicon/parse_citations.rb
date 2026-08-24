# frozen_string_literal: true

module Lexicon
  # This service accepts HTML content reprsenting citations list for a Lexicon Entry and parses it using Deep Seek API
  class ParseCitations < ApplicationService
    include TextLinkExtraction

    SYSTEM_PROMPT = <<PROMPT
  User will send you a set of bibliography records in html form, most of them are in Hebrew, but English and other
  languages are possible. Each record represents single work (e.g. book, or article) about a person, or one of this
  person's works.

  Usually bibliography is represented as a set of <ul> tags, with optional short header before each. Header represents
  subject, and <li> elements inside <ul> represent individual works about this subject.

  You need to parse it and turn into a JSON object with a single key `result` with a value of array of JSON objects
  representing works grouped by subjects:
  ```
  {
    result: [
      { subject: 'Subject 1', works: [ <ARRAY of Works 1> ] },
      { subject: 'Subject 2', works: [ <ARRAY of Works 2> ] },
      ...
    ]
  }
  ```
  Subject should be extracted from the header before <ul> tag and contains only name of the subject work. E.g. if header
  is "about `My Life`", subject must be just "My Life". If there is no header before <ul>, subject should be null.

  Each element in the array of works is a JSON object representing a single bibliography record with the following structure:
  - authors - array of Authors who authored work. Author can be represented as text entry, or as a link to page about
    this author. So an author record contains two string attributes: name (mandatory) and link (optional)
  - title - title of work (e.g. title of article) - mandatory. If whole title is in quotes, remove quotes.
  - from_publication - name of publication where work was published (e.g. name of collection of articles, name of the
    journal where article was published, etc). You should include there additional information helping to identify
    publication, like year and number of issue for journal article, volume number for multivolume collection, etc.
  - pages - string representing page, or pages interval, e.g. "7", "5-12"
  - link - (optional) URL of the work itself, from an inline link on its title (or on other text naming the
    work itself). Do NOT use a link that belongs to the publication the work appeared in -- a link on the
    name of the book, collection or journal reported in `from_publication` is NOT the work's link, and when
    it is the only inline link present `link` must be null. Such links are recovered separately, so nothing
    is lost by leaving them out. Do NOT use the `data-file-link` attribute value for this field either.
  - backup_url - (optional) if the `<li>` element has a `data-file-link` attribute, set this field to that URL.
    Otherwise leave it null.
  - notes - (optional) some additional notes, not fitting into other fields (like 'First published at...')

  Example of work JSON:
  ```
  {
    "authors": [
      {
        "name": "איזיקוביץ, גילי",
        "link": null
      },
      {
        "name": "ארליך, צור",
        "link": "00563.php"
      }
    ],
    "title": "״אני הקלישאה, אין לי ארץ אחרת״",
    "from_publication": "הארץ, גלריה, י״ג באייר תשפ״ג, 4 במאי 2023",
    "pages": "1–3",
    "link": "https://somejournal.com/article.html",
    "notes": "ראיון עם הסופרת גבריאלה אביגור-רותם לרגל צאת ספרה החדש"
  }
  ```
PROMPT

    def call(html)
      Rails.logger.info('Parsing citations HTML with LLM API started.')
      @source_items = []
      html = preprocess_source_items(html)
      chat = RubyLLM.chat(model: 'gpt-4.1-mini')
      chat.with_instructions(SYSTEM_PROMPT).with_params(response_format: { type: :json_object })

      response = chat.ask(html.squish)
      result = []

      json_response = JSON.parse(response.content)
      json_response['result'].each do |subject_works|
        subject = subject_works['subject']
        subject_works['works'].each.with_index do |work, index|
          title = sanitize_smart_quotes(work['title'])
          authors = work['authors'] || []

          # A legacy <li> whose only bold content is a bracketed placeholder standing in for a
          # missing title (e.g. "<b>[ביקורת].</b> <u>ספרות ילדים ונוער</u>, ...") has nothing at
          # all in its author slot, so the LLM reads the placeholder as the author and returns a
          # null title. Promote it back to the title rather than discarding a record that still
          # carries its subject, publication and pages.
          if title.blank? && placeholder_author?(authors)
            title = sanitize_smart_quotes(authors.first['name'])
            authors = []
          end

          if title.blank?
            Rails.logger.warn("ParseCitations: skipping citation with blank title (subject=#{subject.inspect})")
            next
          end

          citation = LexCitation.new(
            subject: sanitize_smart_quotes(subject),
            title: title,
            from_publication: sanitize_smart_quotes(work['from_publication']),
            pages: sanitize_smart_quotes(work['pages']),
            link: work['link'],
            backup_url: work['backup_url'],
            notes: sanitize_smart_quotes(work['notes']),
            seqno: index + 1
          )

          authors.each do |author|
            author = citation.authors.build(name: author['name'], link: author['link'])
            update_link(author)
          end

          result << citation
        end
      end

      # The LLM is unreliable at copying data-file-link into backup_url, so we
      # recover it deterministically from the asterisk links we captured.
      recover_backup_urls(result)
      # The LLM only reports one link per citation, so inline links sitting in other parts of the
      # record (typically the publication the citation appeared in) are recovered separately.
      assign_text_links(result)

      Rails.logger.info('Parsing citations complete.')
      result
    end

    # A bracketed descriptor standing where a title belongs, e.g. "[ביקורת]" (review) or
    # "[מחבר לא מזוהה]" (unidentified author). Kept with its brackets, matching how the same
    # placeholder is already stored when the <li> does have an author to precede it.
    PLACEHOLDER_TITLE = /\A\[.+\]\.?\z/m

    private

    # True when the work's single author is a bracketed placeholder rather than a real name.
    # Only consulted once the title is known to be blank, so a bracketed author accompanying a
    # genuine title (e.g. "[יעוז, חנה]. שיחה עם...") is never disturbed. An author carrying a
    # link is a real entry reference and is left alone, since promoting it would lose the link.
    def placeholder_author?(authors)
      return false unless authors.size == 1

      authors.first['link'].blank? && authors.first['name'].to_s.strip.match?(PLACEHOLDER_TITLE)
    end

    def update_link(author)
      return if author.link.blank?

      match = author.link.match(%r{/lex/entries/(?<entry_id>\d+)})
      if match.present?
        entry_id = match[:entry_id]
        entry = LexEntry.find_by(id: entry_id)
        if entry.present? && entry.entry_type == :person
          # name used for Author can be different from entry title (e.g. alias)
          author.name = nil if author.name == entry.title
          author.link = nil
          author.entry = entry
        end
      end
    end

    def sanitize_smart_quotes(text)
      text&.gsub(/[\u201C\u201D\u05F4]/, 34.chr)&.gsub(/[\u2018\u2019]/, 39.chr)
    end

    # Records every citation <li> of the source -- its text, its inline anchors, and the backup
    # file its asterisk link points at -- so that data the LLM drops or misfiles can be recovered
    # deterministically and joined back to the parsed citation. Asterisk anchors are moved into a
    # data-file-link attribute and removed, since the LLM otherwise mistakes them for the
    # citation's own link.
    def preprocess_source_items(html)
      doc = Nokogiri::HTML::DocumentFragment.parse(html)
      modified = false
      doc.css('li').each do |li|
        anchors = own_anchors(li)
        asterisk_links = anchors.select { |a| a.text =~ /\A[[:space:]]*\*[[:space:]]*\z/ }
        inline_anchors = anchors - asterisk_links
        backup_href = asterisk_links.map { |a| a['href'] }.find(&:present?)
        li['data-file-link'] = backup_href if backup_href.present?

        if backup_href.present? || inline_anchors.present?
          # Inline (non-asterisk) hrefs are the citation's own links and serve as
          # the strongest join key back to the LLM-parsed citation.
          inline_hrefs = inline_anchors.filter_map { |a| a['href'].presence }
          @source_items << {
            backup_href: backup_href,
            anchors: inline_anchors.map { |a| { text: a.text.squish, href: a['href'] } },
            inline_hrefs: inline_hrefs.reject { |h| h.end_with?('.php') || h.start_with?('#') },
            text: own_text(li)
          }
        end

        next if asterisk_links.empty?

        modified = true
        asterisk_links.each(&:remove)
      end
      modified ? doc.to_html : html
    end

    # Anchors belonging to this <li> itself, excluding those of any nested <li>.
    # Legacy pages nest a sub-list of citations inside the <li> of the work they
    # are about, so a plain descendant selector would credit an inner citation's
    # asterisk link (and its inline links) to the outer <li> — and, since the
    # anchor is then removed, the inner <li> would never be recorded at all.
    def own_anchors(list_item)
      list_item.css('a').select { |a| a.ancestors('li').first == list_item }
    end

    # Text of this <li> without the text of any nested <li>, so that match_by_text
    # cannot match a nested citation's title against its containing work's <li>.
    def own_text(list_item)
      copy = list_item.dup
      copy.css('li').each(&:remove)
      normalize_text(copy.text)
    end

    # Deterministically assign backup_url to the citation each asterisk link came
    # from, since the LLM frequently omits it. Each backup is assigned at most
    # once, preferring an exact match on the citation's inline link and falling
    # back to a title/text containment match.
    def recover_backup_urls(citations)
      assigned = Set.new
      @source_items.each do |item|
        next if item[:backup_href].blank?

        citation = match_source_item(citations, item, assigned)
        next if citation.nil?

        citation.backup_url = item[:backup_href]
        assigned << citation.object_id
      end
    end

    # Restores the inline links of each source <li> that the LLM did not report, as text→link
    # pairs on the citation it came from. Links already stored in a column of their own (the
    # citation's link or backup file) or as one of its authors are skipped.
    def assign_text_links(citations)
      # Mirrors the guard ParsePersonWork uses for title_links/comment_links: skip quietly on an
      # environment whose lex_citations table has not been migrated yet, rather than failing the
      # whole ingestion.
      return unless LexCitation.new.respond_to?(:text_links=)

      assigned = Set.new
      @source_items.each do |item|
        next if item[:anchors].empty?

        citation = match_source_item(citations, item, assigned)
        next if citation.nil?

        assigned << citation.object_id
        links = item[:anchors].filter_map { |anchor| text_link_for(citation, anchor) }
        citation.text_links = links.uniq { |link| link['text'] }.presence
      end
    end

    def text_link_for(citation, anchor)
      text = anchor[:text]
      href = anchor[:href]
      return nil if text.blank? || href.blank?
      return nil if already_captured?(citation, text, href)

      build_text_link(text, href)
    end

    # True when the anchor is already preserved elsewhere on the citation: as its own link, as its
    # backup file, or as one of its authors (who carry their own entry/link).
    def already_captured?(citation, text, href)
      return true if [citation.link, citation.backup_url].compact_blank
                                                         .any? { |url| normalize_url(url) == normalize_url(href) }

      citation.authors.any? do |author|
        (author.link.present? && normalize_url(author.link) == normalize_url(href)) ||
          (author.entry.present? && author.entry.id == href_entry_id(href)) ||
          (author.display_name.present? && normalize_text(author.display_name) == normalize_text(text))
      end
    end

    # Finds the citation a source <li> was parsed into: preferring an exact match on the
    # citation's inline link, and falling back to a title/text containment match. Each citation is
    # matched at most once per pass.
    def match_source_item(citations, item, assigned)
      match_by_link(citations, item, assigned) || match_by_text(citations, item, assigned)
    end

    def match_by_link(citations, item, assigned)
      return nil if item[:inline_hrefs].empty?

      hrefs = item[:inline_hrefs].map { |h| normalize_url(h) }
      citations.find do |c|
        c.link.present? && assigned.exclude?(c.object_id) && hrefs.include?(normalize_url(c.link))
      end
    end

    # Fallback: pick the not-yet-assigned citation whose (sufficiently long)
    # title appears within the source <li> text. Longest title wins to avoid
    # matching a short, generic title contained in several entries.
    def match_by_text(citations, item, assigned)
      candidates = citations.select do |c|
        next false if assigned.include?(c.object_id)

        title = normalize_text(c.title)
        title.length >= 8 && item[:text].include?(title)
      end
      candidates.max_by { |c| normalize_text(c.title).length }
    end

    def normalize_url(url)
      url&.strip&.chomp('/')
    end

    def normalize_text(text)
      return '' if text.blank?

      text.gsub(/[[:punct:]]/, ' ').gsub(/\s+/, ' ').strip
    end
  end
end
