# frozen_string_literal: true

module Lexicon
  # Service to ingest Lexicon Person from php file
  class IngestPerson < IngestBase
    EDITED_HEADER = 'עריכה:'
    TRANSLATED_HEADER = 'תרגום:'

    def create_lex_item(html_doc)
      lex_person = LexPerson.new(citations: Lexicon::ExtractCitations.call(html_doc))

      heading_table = html_doc.at_css('table[width="100%"]')
      heading_table_html = heading_table.to_html
      # Match both patterns: (YYYY) and (YYYY-YYYY)
      if (match = heading_table_html.match(%r{<font size="4"[^>]*>\s*\((\d{4})(?:־(\d{4}))?\)\s*</font>}))
        lex_person.birthdate = match[1]
        lex_person.deathdate = match[2]
      end

      if heading_table.parent.name == 'span'
        heading_table = heading_table.parent
      end

      next_elem = heading_table.next_element
      bio = []
      while next_elem.present? && !works_header?(next_elem)
        bio << next_elem.to_html
        next_elem = next_elem.next_element
      end

      lex_person.bio = HtmlToMarkdown.call(bio.join("\n"))

      if next_elem.present? && works_header?(next_elem)
        parse_person_works(next_elem, lex_person)
      end

      buf = html_doc.to_html
      parse_person_links(lex_person, buf[%r{a name="links".*?</ul}m])

      # We need to save the person and its citations and works before linking citations to works
      # to avoid validation errors
      lex_person.save!

      link_citations_to_works(lex_person)
      lex_person
    end

    private

    def link_citations_to_works(lex_person)
      lex_person.citations.each do |citation|
        subject = citation.subject

        next if subject.blank?

        # For now, we're only checking for an exact title match
        # We can also consider using more advanced matching techniques if needed to handle typos, etc.
        work = lex_person.works.detect { |w| w.title == subject }

        next if work.nil?

        citation.person_work = work
        citation.subject = nil # clear the subject since it's now linked to PersonWork
        citation.save!
      end
    end

    def header?(elem)
      %w(p font).include?(elem.name) && elem.at_css('a[name]')
    end

    def works_header?(elem)
      header?(elem) && elem.at_css('a[name="Books"]')
    end

    def parse_person_works(works_header, lex_person)
      next_elem = works_header.next_element
      if next_elem.present? && next_elem.name == 'span'
        next_elem = next_elem.first_element_child
      end

      work_type = :original
      while next_elem.present? && !header?(next_elem)
        if next_elem.name == 'p'
          if next_elem.text.strip == EDITED_HEADER
            work_type = :edited
          elsif next_elem.text.strip == TRANSLATED_HEADER
            work_type = :translated
          end
        elsif next_elem.name == 'ul'
          next_elem.css('li').each do |li|
            work = ParsePersonWork.call(li.text)
            work.work_type = work_type
            lex_person.works << work
          end
        else
          Rails.logger.warn('Unexpected element while parsing person works: ' + next_elem.name)
        end
        next_elem = next_elem.next_element
      end

      next_elem
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

        person.links.build(
          url: ::Regexp.last_match(2),
          description: "#{html2txt(::Regexp.last_match(1))} #{html2txt(::Regexp.last_match(3))} " \
                       "#{html2txt(::Regexp.last_match(4))}"
        )
      end
    end
  end
end
