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
  - link - (optional) sometimes the HTML will contain a link to the actual work or article.
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
      chat = RubyLLM.chat(model: 'gpt-4.1-mini')
      chat.with_instructions(SYSTEM_PROMPT).with_params(response_format: { type: :json_object })

      response = chat.ask(html.squish)
      result = []

      json_response = JSON.parse(response.content)
      json_response['result'].each do |subject_works|
        subject = subject_works['subject']
        subject_works['works'].each.with_index do |work, index|
          citation = LexCitation.new(
            subject: sanitize_smart_quotes(subject),
            title: sanitize_smart_quotes(work['title']),
            from_publication: sanitize_smart_quotes(work['from_publication']),
            pages: sanitize_smart_quotes(work['pages']),
            link: work['link'],
            notes: sanitize_smart_quotes(work['notes']),
            seqno: index + 1
          )

          work['authors'].each do |author|
            citation.authors.build(name: author['name'], link: author['link'])
          end

          result << citation
        end
      end
      Rails.logger.info('Parsing citations complete.')
      result
    end

    private

    def sanitize_smart_quotes(text)
      text&.gsub(/[“”״]/, '"')&.gsub(/[‘’]/, "'")
    end
  end
end
