# frozen_string_literal: true

module Lexicon
  # This service accepts HTML content reprsenting citations list for a Lexicon Entry and parses it using Deep Seek API
  class ParseCitations < ApplicationService
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
  - link - (optional) URL of the article or work, from an inline link in the citation text (title or other
    anchor). Do NOT use the `data-file-link` attribute value for this field.
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
      @asterisk_backups = []
      html = preprocess_asterisk_links(html)
      chat = RubyLLM.chat(model: 'gpt-4.1-mini')
      chat.with_instructions(SYSTEM_PROMPT).with_params(response_format: { type: :json_object })

      response = chat.ask(html.squish)
      result = []

      json_response = JSON.parse(response.content)
      json_response['result'].each do |subject_works|
        subject = subject_works['subject']
        subject_works['works'].each.with_index do |work, index|
          title = sanitize_smart_quotes(work['title'])
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

          work['authors'].each do |author|
            author = citation.authors.build(name: author['name'], link: author['link'])
            update_link(author)
          end

          result << citation
        end
      end

      # The LLM is unreliable at copying data-file-link into backup_url, so we
      # recover it deterministically from the asterisk links we captured.
      recover_backup_urls(result)

      Rails.logger.info('Parsing citations complete.')
      result
    end

    private

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

    def preprocess_asterisk_links(html)
      doc = Nokogiri::HTML::DocumentFragment.parse(html)
      modified = false
      doc.css('li').each do |li|
        asterisk_links = li.css('a').select { |a| a.text.strip == '*' }
        next if asterisk_links.empty?

        modified = true
        href = asterisk_links.map { |a| a['href'] }.find(&:present?)

        # Record the asterisk backup before removing the anchors, so we can
        # re-attach it to the parsed citation deterministically afterwards.
        # Inline (non-asterisk) hrefs are the citation's own links and serve as
        # the strongest join key back to the LLM-parsed citation.
        if href.present?
          li['data-file-link'] = href
          inline_hrefs = (li.css('a').to_a - asterisk_links).filter_map { |a| a['href'].presence }
          @asterisk_backups << {
            backup_href: href,
            inline_hrefs: inline_hrefs.reject { |h| h.end_with?('.php') || h.start_with?('#') },
            text: normalize_text(li.text)
          }
        end

        asterisk_links.each(&:remove)
      end
      modified ? doc.to_html : html
    end

    # Deterministically assign backup_url to the citation each asterisk link came
    # from, since the LLM frequently omits it. Each backup is assigned at most
    # once, preferring an exact match on the citation's inline link and falling
    # back to a title/text containment match.
    def recover_backup_urls(citations)
      return if @asterisk_backups.blank?

      assigned = Set.new
      @asterisk_backups.each do |backup|
        citation = match_by_link(citations, backup, assigned) ||
                   match_by_text(citations, backup, assigned)
        next if citation.nil?

        citation.backup_url = backup[:backup_href]
        assigned << citation.object_id
      end
    end

    def match_by_link(citations, backup, assigned)
      return nil if backup[:inline_hrefs].empty?

      hrefs = backup[:inline_hrefs].map { |h| normalize_url(h) }
      citations.find do |c|
        c.link.present? && assigned.exclude?(c.object_id) && hrefs.include?(normalize_url(c.link))
      end
    end

    # Fallback: pick the not-yet-assigned citation whose (sufficiently long)
    # title appears within the source <li> text. Longest title wins to avoid
    # matching a short, generic title contained in several entries.
    def match_by_text(citations, backup, assigned)
      candidates = citations.select do |c|
        next false if assigned.include?(c.object_id)

        title = normalize_text(c.title)
        title.length >= 8 && backup[:text].include?(title)
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
