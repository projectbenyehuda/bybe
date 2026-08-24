# frozen_string_literal: true

module Lexicon
  # Service to ingest Lexicon Person from php file
  class IngestPerson < IngestBase
    include HtmlUtils

    WORKS_HEADER = 'Books'
    CITATIONS_HEADER = 'Bib.'

    # The links section is normally introduced by an <a name="links"> anchor, but a handful of
    # legacy files spell the anchor differently (e.g. `name="links."`) or omit it entirely and
    # carry only the Hebrew "קישורים:" heading. Patterns are tried in order, so the anchor always
    # wins when present.
    LINKS_SECTION_PATTERNS = [
      %r{a name="links[^"]*".*?</ul}m,
      %r{<font[^>]*>\s*קישורים\s*:?\s*</font>.*?</ul}m
    ].freeze

    # Maps 00000_files logo filenames to Hebrew site names for img tags that lack alt text.
    IMG_LOGO_TEXT = {
      'Ben-Yehuda-s.jpg' => 'פרויקט בן יהודה',
      'dafdaf.gif' => 'דפדף',
      'icast-free.png' => 'icast',
      'icast-logo.png' => 'icast',
      'icast-od.jpg' => 'icast',
      'nli.png' => 'הספרייה הלאומית',
      'onesh.jpg' => 'עונג שבת',
      'pdf_icon.gif' => 'PDF',
      'text.gif' => 'טקסט',
      'ynet.gif' => 'Ynet',
      'youtube.jpg' => 'YouTube'
    }.freeze

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
        if cell_node
          cell_text = cell_node.text.gsub(/\s+/, ' ').strip
          if (match = cell_text.match(/\((\d{4})(?:[-–־](\d{4}))?\)/))
            lex_person.birthdate = match[1]
            lex_person.deathdate = match[2]
          end
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
        bio << bio_html(next_elem)
        next_elem = next_elem.next_element
      end

      # Bio was inside the wrapping span but the works header is outside it.
      # Continue from span siblings to find the works header.
      if next_elem.nil? && !at_span_level && heading_table.parent.name == 'span'
        next_elem = heading_table.parent.next_element
        while next_elem.present? && !header?(next_elem, WORKS_HEADER)
          bio << bio_html(next_elem)
          next_elem = next_elem.next_element
        end
      end

      lex_person.bio = HtmlToMarkdown.call(bio.compact.join("\n"))

      if next_elem.present? && header?(next_elem, WORKS_HEADER)
        Lexicon::ExtractPersonWorks.call(next_elem, lex_person)
      end

      lex_person.gender = @female ? :female : :male

      # We need to save the person and its citations and works before linking citations to works
      # to avoid validation errors
      lex_person.save!

      # Authority can already be filled in ExtractAuthority service so we call AssociateAuthority only if it is nil.
      # Pass @lex_entry.title explicitly: at this point the DB association between LexPerson and LexEntry
      # has not been committed yet (lex_entry.lex_item= is set after create_lex_item returns), so
      # lex_person.entry would return nil inside AssociateAuthority.
      AssociateAuthority.call(lex_person, html_doc, entry_title: @lex_entry&.title) if lex_person.authority.nil?

      # Links are parsed only after the authority is known, so that links pointing at this entry's
      # own authority page on benyehuda.org can be skipped (see #redundant_authority_link?).
      parse_person_links(lex_person, links_section_html(html_doc.to_html))
      lex_person.save!

      link_citations_to_works(lex_person)
      attach_backup_files(lex_person)
      # A bibliography we failed to parse leaves the entry with no citations and no error at all,
      # so record the discrepancy where the migration queue can show it.
      FlagUnmigratedCitations.call(@lex_file, lex_person, html_doc.to_html)
      lex_person
    end

    private

    # HTML of a single bio element, with content-free tables dropped: nil when the element
    # is itself such a table, otherwise its markup minus any it contains. The element is
    # copied before pruning, so the document the rest of the ingestion reads stays intact.
    def bio_html(elem)
      return nil if content_free_table?(elem)
      return elem.to_html if elem.css('table').none? { |table| content_free_table?(table) }

      copy = elem.dup
      copy.css('table').each { |table| table.remove if content_free_table?(table) }
      copy.to_html
    end

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

    # Returns the markup of the links section, or nil when the entry has no links section at all.
    def links_section_html(buf)
      LINKS_SECTION_PATTERNS.each do |pattern|
        section = buf[pattern]
        return section if section.present?
      end
      nil
    end

    def parse_person_links(person, buf)
      # Entries without a links section at all are legitimate; there is simply nothing to migrate.
      return if buf.blank?

      html_entities_coder = HTMLEntities.new

      buf.scan(%r{<li>(.*?)</li>}m).map do |x|
        if x.instance_of?(Array)
          html_entities_coder.decode(x[0].gsub(/<font.*?>/, '').gsub('</font>', ''))
        else
          ''
        end
      end.map do |linkstring|
        next unless linkstring =~ %r{(.*?)<a .*?href="(.*?)".*?>(.*?)</a>(.*)}m

        url = ::Regexp.last_match(2)
        before, label, after = ::Regexp.last_match.values_at(1, 3, 4)

        next if redundant_authority_link?(url, person)

        person.links.build(
          url: url,
          description: "#{html2txt(img_to_text(before))} " \
                       "#{html2txt(img_to_text(label))} " \
                       "#{html2txt(img_to_text(after))}"
        )
      end
    end

    # Links pointing at the entry's own Authority page on benyehuda.org are not migrated:
    # the entry is already associated with that Authority, so the link is redundant. Links to
    # other benyehuda.org authorities (or to non-author pages) are migrated as usual.
    def redundant_authority_link?(url, person)
      person.authority.present? && BenyehudaLinks.authority_for(url) == person.authority
    end

    def img_to_text(html)
      html.gsub(/<img\b[^>]*>/i) do |img_tag|
        alt = img_tag[/\balt="([^"]*)"/i, 1].to_s.strip
        next alt if alt.present?

        filename = File.basename(img_tag[/\bsrc="([^"]*)"/i, 1].to_s)
        IMG_LOGO_TEXT[filename].to_s
      end
    end
  end
end
