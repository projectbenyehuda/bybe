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

  You need to parse it and turn into a JSON object with a single key `result` with a value of array of JSON objects#{' '}
  representing works grouped by subjects:
  ```
  {#{' '}
    result: [
      { subject: 'Subject 1', works: [ <ARRAY of Works 1> ] },
      { subject: 'Subject 2', works: [ <ARRAY of Works 2> ] },
      ...
    ]
  }
  ```

  Each element in the array of works is a JSON object representing a single bibliography record with the following structure:
  - authors - array of Authors who authored work. Author can be represented as text entry, or as a link to page about
    this author. So an author record contains two string attributes: name (mandatory) and link (optional)
  - title - title of work (e.g. title of article) - mandatory
  - from_publication - name of publication where work was published (e.g. name of collection of articles, name of the
    journal where article was published, etc). You should include there additional information helping to identify
    publication, like year and number of issue for journal article, volume number for multivolume collection, etc.
  - pages - string representing page, or pages interval, e.g. "7", "5-12"
  - link - (optional) sometimes the HTML will contain a link to the actual work or article.
  - notes - (optional) some additional notes, not fitting into other fields (like 'First published at...')
  - raw - HTML markup representing content of <li> tag representing this work (without the wrapping <li>, </li> tags)

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
    "raw": "<HTML content>"
  }
  ```
PROMPT

    def call(html)
      chat = RubyLLM.chat(model: 'gpt-4.1-mini')
      chat.with_instructions(SYSTEM_PROMPT).with_params(response_format: { type: :json_object })

      response = call_with_retry { chat.ask(html.squish) }
      result = []

      json_response = JSON.parse(response.content)
      json_response['result'].each do |subject_works|
        subject = subject_works['subject']
        subject_works['works'].each do |work|
          authors = work['authors']

          if authors.size > 1
            # Do we have such cases?
            raise 'Multiple authors not supported yet'
          end

          author_name = authors.first['name'] if authors.any?
          lex_person = find_or_create_lex_person_by_author_name(author_name) if author_name

          result << LexCitation.new(
            status: :ai_parsed,
            raw: sanitize_smart_quotes(work['raw']),
            subject: sanitize_smart_quotes(subject),
            title: sanitize_smart_quotes(work['title']),
            from_publication: sanitize_smart_quotes(work['from_publication']),
            pages: sanitize_smart_quotes(work['pages']),
            link: work['link'],
            notes: sanitize_smart_quotes(work['notes']),
            authors: author_name,
            lex_person: lex_person
          )
        end
      end
      result
    end

    private

    def find_or_create_lex_person_by_author_name(author_name)
      return nil if author_name.blank?

      # transpose name parts if in "Last, First" format
      if author_name.include?(',') && author_name.index(',') < author_name.length - 2
        parts = author_name.split(',', 2).map(&:strip)
        author_name = "#{parts[1]} #{parts[0]}"
      end
      # Find authorities where name matches or other_designation contains the name
      # Note: other_designation can contain multiple names separated by semicolons
      matching_authorities = Authority.published.where(
        'name = ? OR other_designation LIKE ? OR other_designation LIKE ? OR other_designation = ?',
        author_name,
        "#{author_name};%", # name at start
        "%; #{author_name};%", # name in middle
        author_name # exact match if other_designation has single name
      ).limit(2) # We only need to know if there's 1 or more than 1

      # Additional filtering: check if author_name is actually one of the semicolon-separated values
      exact_matches = matching_authorities.select do |authority|
        authority.name == author_name ||
          authority.other_designation&.split(';')&.map(&:strip)&.include?(author_name)
      end

      # Only link if exactly one authority matches
      return nil unless exact_matches.size == 1

      authority_id = exact_matches.first.id
      LexPerson.find_or_create_by_authority_id(authority_id)
    end

    def sanitize_smart_quotes(text)
      return nil if text.nil?

      text.gsub(/[“”״]/, '"').gsub(/[‘’]/, "'")
    end

    def call_with_retry(max_retries: 3, &block)
      retries = 0
      begin
        yield
      rescue Faraday::SSLError, Faraday::ConnectionFailed, Faraday::TimeoutError, Errno::ECONNRESET => e
        retries += 1
        if retries < max_retries
          wait_time = 2**retries # exponential backoff: 2s, 4s, 8s
          Rails.logger.warn("LLM API call failed (attempt #{retries}/#{max_retries}): #{e.class} - #{e.message}. Retrying in #{wait_time}s...")
          sleep(wait_time)
          retry
        else
          Rails.logger.error("LLM API call failed after #{max_retries} attempts: #{e.class} - #{e.message}")
          raise
        end
      end
    end
  end
end
