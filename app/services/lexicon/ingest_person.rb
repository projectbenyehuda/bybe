# frozen_string_literal: true

module Lexicon
  # Service to ingest Lexicon Person from php file
  class IngestPerson < IngestBase
    include HtmlUtils

    WORKS_HEADER = 'Books'
    CITATIONS_HEADER = 'Bib.'

    def call(lex_file)
      raw = File.read(lex_file.full_path, encoding: 'UTF-8')
      @female = raw.include?('על המחברת ויצירתה')
      super
    end

    def create_lex_item(html_doc)
      lex_person = LexPerson.new(citations: Lexicon::ExtractCitations.call(html_doc))

      lex_person.authority = Lexicon::ExtractAuthority.call(html_doc)

      heading_table = html_doc.at_css('table[width="100%"]')
      heading_table_html = heading_table.to_html
      # Match both patterns: (YYYY) and (YYYY-YYYY); handles maqaf, en-dash, hyphen
      if (match = heading_table_html.match(%r{<font size="4"[^>]*>\s*\((\d{4})(?:[-–־](\d{4}))?\)\s*</font>}))
        lex_person.birthdate = match[1]
        lex_person.deathdate = match[2]
      end

      # Fallback: years may be split across multiple font elements (e.g. tsifroni.php).
      # Parse from the heading cell's plain text instead.
      if lex_person.birthdate.blank? && heading_table.present?
        cell_node = heading_table.at_css('td p[align="center"]')
        cell_text = cell_node&.text&.gsub(/\s+/, ' ')&.strip
        if (match = cell_text&.match(/\((\d{4})(?:[-–־](\d{4}))?\)/))
          lex_person.birthdate = match[1]
          lex_person.deathdate = match[2]
        end
      end

      # Bio content may be inside a wrapping span (as siblings of the heading table),
      # or outside the span (as siblings of the span itself). We first iterate table
      # siblings; if exhausted, we fall through to span siblings to find remaining bio
      # and the works header.
      next_elem = heading_table.next_element
      at_span_level = false

      # When the table has no siblings inside its wrapping span, jump directly
      # to the span's siblings where bio content lives.
      if next_elem.nil? && heading_table.parent.name == 'span'
        next_elem = heading_table.parent.next_element
        at_span_level = true
      end

      bio = []
      while next_elem.present? && !header?(next_elem, WORKS_HEADER)
        bio << next_elem.to_html
        next_elem = next_elem.next_element
      end

      # Bio was inside the wrapping span but the works header is outside it.
      # Continue from span siblings to find the works header.
      if next_elem.nil? && !at_span_level && heading_table.parent.name == 'span'
        next_elem = heading_table.parent.next_element
        while next_elem.present? && !header?(next_elem, WORKS_HEADER)
          bio << next_elem.to_html
          next_elem = next_elem.next_element
        end
      end

      lex_person.bio = HtmlToMarkdown.call(bio.join("\n"))

      if next_elem.present? && header?(next_elem, WORKS_HEADER)
        Lexicon::ExtractPersonWorks.call(next_elem, lex_person)
      end

      buf = html_doc.to_html
      parse_person_links(lex_person, buf[%r{a name="links".*?</ul}m])

      lex_person.gender = @female ? :female : :male

      # We need to save the person and its citations and works before linking citations to works
      # to avoid validation errors
      lex_person.save!

      # Authority can already be filled in ExtractAuthority service so we call AssociateAuthority only if it is nil.
      # Pass @lex_entry.title explicitly: at this point the DB association between LexPerson and LexEntry
      # has not been committed yet (lex_entry.lex_item= is set after create_lex_item returns), so
      # lex_person.entry would return nil inside AssociateAuthority.
      AssociateAuthority.call(lex_person, html_doc, entry_title: @lex_entry&.title) if lex_person.authority.nil?
      link_citations_to_works(lex_person)
      attach_backup_files(lex_person)
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

    def attach_backup_files(lex_person)
      lex_person.citations.each do |citation|
        next if citation.backup_url.blank?

        url = citation.backup_url.split('#').first
        legacy_link = LexLegacyLink.find_by(new_path: url)
        next if legacy_link.nil?

        blob = legacy_link.lex_entry.blob_by_filename(File.basename(url))
        next if blob.nil?

        citation.backup_file.attach(blob)
        citation.save!
      end
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
        next unless linkstring =~ %r{(.*?)<a .*?href="(.*?)".*?>(.*?)</a>(.*)}m

        person.links.build(
          url: ::Regexp.last_match(2),
          description: "#{html2txt(::Regexp.last_match(1))} #{html2txt(::Regexp.last_match(3))} " \
                       "#{html2txt(::Regexp.last_match(4))}"
        )
      end
    end
  end
end
