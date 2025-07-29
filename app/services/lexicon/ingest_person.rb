# frozen_string_literal: true

module Lexicon
  class IngestPerson < ApplicationService
    def call(file_id)
      file = LexFile.find(file_id)
      lex_entry = LexEntry.create!(
        title: file.title,
        sort_title: file.title.strip_nikkud.tr('-־[]()*"\'', '').strip,
        status: :raw
      )
      file.lex_entry = lex_entry
      file.status_ingested!

      lex_person = create_lex_person_from_html(lex_entry, file)
      lex_entry.lex_item = lex_person
      lex_entry.save!

      lex_entry
    end

    private

    def parse_person_bio(buf)
      ActionView::Base.full_sanitizer.sanitize(buf)
    end

    def parse_person_books(buf)
      buf.scan(%r{<li>(.*?)</li>}m).map do |x|
        if x.class == Array
          PandocRuby.convert(
            x[0],
            M: 'dir=rtl',
            from: :html,
            to: :markdown_mmd
          ).gsub("\n", ' ').force_encoding('UTF-8')
        else
          ''
        end
      end.join("\n")
    end

    def parse_person_bib(buf)
      buf.scan(%r{<li>(.*?)</li>}m).map do |x|
        if x.class == Array
          PandocRuby.convert(
            x[0],
            M: 'dir=rtl',
            from: :html,
            to: :markdown_mmd
          ).gsub("\n", ' ').force_encoding('UTF-8')
        else
          ''
        end
      end.join("\n")
    end

    def create_lex_person_from_html(entry, lexfile)
      return entry.lex_item if entry.lex_item.present?

      buf = File.read(lexfile.full_path)
      # anchors = buf.scan(/<a name="(.*?)">/)
      # ret['links'] = parse_links(buf[/a name="links".*?<\/ul/m])
      lex_person = LexPerson.create!(
        bio: parse_person_bio(buf[%r{</table>.*?<a name="Books}m]),
        works: parse_person_books(buf[/a name="Books".*?<a name/m]),
        about: parse_person_bib(buf[/a name="Bib.".*?<a name/m])
      )

      parse_person_links(lex_person, buf[%r{a name="links".*?</ul}m])
      lex_person
    end

    def parse_person_links(person, buf)
      html_entities_coder = HTMLEntities.new

      buf.scan(%r{<li>(.*?)</li>}m).map do |x|
        if x.class == Array
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
