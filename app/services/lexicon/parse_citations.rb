# frozen_string_literal: true

module Lexicon
  # This service accepts HTML content reprsenting citations list for a Lexicon Entry and parses it using Deep Seek API
  class ParseCitations < ApplicationService
    SYSTEM_PROMPT = <<PROMPT
  User will send you a set of bibliography records in html form, most of them are in Hebrew, but English and other
  languages are possible. Each record represents single work (e.g. book, or article) about a person, or one of this
  person's works.

  Usually bibliography is represented as set of <ul> tags, with optional short header before each. Header represents
  subject, and <li> elements inside <ul> represents individual work about this subject.

  You need to parse it and turn into an JSON object with a single key `result` with a value of array of JSON objects 
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

  Each element in array of works is a JSON object representing single bibliography record with following structure:
  - authors - array of Authors who authored work. Author can be represented as text entry, or as a link to page about
    this author. So author record contains two string attributes: name (mandatory) and link (optional)
  - title - title of work (e.g. title of article) - mandatory
  - from_publication - name of publication where work was published (e.g. name of collection of articles, name of the
    journal where article was published, etc). You should include there additional information helping to identify
    publication, like year and number of issue for journal article, volume number for multivolume collection, etc.
  - pages - string representing page, or pages interval, e.g. "7", "5-12"
  - link - (optional) sometimes html will contain a link to actual work or article.
  - notes - (optional) some additional notes, not fitting into other fields (like 'First published at...')
  - raw - HTML markup representing content of <li> tag representing this work (without wrapping <li>, </li> tags)

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

      response = chat.ask(html.squish)
      result = []

      json_response = JSON.parse(response.content)
      json_response['result'].each do |subject_works|
        subject = subject_works['subject']
        subject_works['works'].each do |work|
          if work['authors'].size > 1
            raise 'Multiple authors not supported yet'
          end

          result << LexCitation.new(
            status: :ai_parsed,
            raw: work['raw'],
            subject: subject,
            title: work['title'],
            from_publication: work['from_publication'],
            pages: work['pages'],
            link: work['link'],
            notes: work['notes'],
            authors: work['authors'] = work['authors'].first['name']
          )
        end
      end
      result
    end
  end
end
