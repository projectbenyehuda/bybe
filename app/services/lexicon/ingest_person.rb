# frozen_string_literal: true

module Lexicon
  # Service to ingest Lexicon Person from php file
  class IngestPerson < ApplicationService
    def call(file_id)
      file = LexFile.find(file_id)
      lex_entry = LexEntry.create(
        title: file.title,
        status: :raw
      )

      html_doc = File.open(file.full_path) { |f| Nokogiri::HTML(f) }
      AttachImages.call(html_doc, lex_entry)

      lex_person = create_lex_person_from_html(lex_entry, html_doc.to_html)
      lex_entry.lex_item = lex_person
      lex_entry.save!

      file.lex_entry = lex_entry
      file.status_ingested!

      lex_entry
    end

    private

    def parse_person_bio(buf)
      HtmlToMarkdown.call(ActionView::Base.full_sanitizer.sanitize(buf))
    end

    def parse_person_books(buf)
      buf.scan(%r{<li>(.*?)</li>}m).map do |x|
        if x.instance_of?(Array)
          HtmlToMarkdown.call(x[0]).gsub("\n", ' ')
        else
          ''
        end
      end.join("\n")
    end

    def parse_person_bib(buf)
      buf.scan(%r{<li>(.*?)</li>}m).map do |x|
        if x.instance_of?(Array)
          HtmlToMarkdown.call(x[0]).gsub("\n", ' ')
        else
          ''
        end
      end.join("\n")
    end

    def create_lex_person_from_html(entry, buf)
      return entry.lex_item if entry.lex_item.present?

      # anchors = buf.scan(/<a name="(.*?)">/)
      # ret['links'] = parse_links(buf[/a name="links".*?<\/ul/m])
      lex_person = LexPerson.new(
        bio: parse_person_bio(buf[%r{</table>.*?<a name="Books}m]),
        works: parse_person_books(buf[/a name="Books".*?<a name/m]),
        about: parse_person_bib(buf[/a name="Bib.".*?<a name/m])
      )

      # Match both patterns: (YYYY) and (YYYY-YYYY)
      if (match = buf.match(%r{<font size="4"[^>]*>\s*\((\d{4})(?:־(\d{4}))?\)\s*</font>}))
        lex_person.birthdate = match[1]
        lex_person.deathdate = match[2]
      end

      lex_person.save!

      parse_person_links(lex_person, buf[%r{a name="links".*?</ul}m])
      lex_person
    end

    def parse_person_links(person, buf)
      html_entities_coder = HTMLEntities.new

      buf.scan(%r{<li>(.*?)</li>}m).map do |x|
        if x.instance_of?(Array)
          html_entities_coder.decode(x[0].gsub(/<font.*?>/, '').gsub('</font>', ''))
        else
          ''
        end
      end.map do |linkstring|
        next unless linkstring =~ %r{(.*?)<a .*? href="(.*?)".*?>(.*?)</a>(.*)}m

        person.lex_links.create!(
          url: ::Regexp.last_match(2),
          description: "#{html2txt(::Regexp.last_match(1))} #{html2txt(::Regexp.last_match(3))} " \
                       "#{html2txt(::Regexp.last_match(4))}"
        )
      end
    end
  end
end
