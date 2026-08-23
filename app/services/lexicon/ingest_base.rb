# frozen_string_literal: true

module Lexicon
  # Base class for php file ingestion
  class IngestBase < ApplicationService
    LAST_UPDATE_LABEL = 'עודכן לאחרונה'
    LAST_UPDATE_RE = /#{LAST_UPDATE_LABEL}:?\s*([^\]\r\n]*)/

    def call(lex_file)
      @lex_file = lex_file
      @lex_entry = lex_file.lex_entry

      html_doc = HtmlUtils.parse_file(lex_file.full_path)
      Lexicon::AttachImages.call(html_doc, @lex_entry)
      Lexicon::ProcessLinks.call(html_doc, @lex_entry)

      @lex_entry.lex_item = create_lex_item(html_doc)
      @lex_entry.english_title = extract_english_title(html_doc)
      @lex_entry.external_identifiers = extract_external_identifiers(html_doc)
      @lex_entry.date_of_manual_update = extract_date_of_manual_update(html_doc)
      @lex_entry.migration_item_count = compute_migration_item_count
      @lex_entry.status_draft!

      lex_file.status_ingested!

      Lexicon::CheckExternalLinksJob.perform_later(@lex_entry.id)

      @lex_entry
    end

    def create_lex_item(_html_doc)
      raise('Not implemented')
    end

    private

    def compute_migration_item_count
      lex_item = @lex_entry.lex_item
      count = 0
      count += lex_item.works.count if lex_item.respond_to?(:works)
      count += lex_item.citations.count if lex_item.respond_to?(:citations)
      count += lex_item.links.count
      count += @lex_entry.attachments.count
      count
    end

    # Extract the "עודכן לאחרונה:" date string from the PHP footer area.
    # The label may be surrounded by brackets (e.g. "[עודכן לאחרונה: DATE]") and the colon is
    # missing in a handful of files. We search the whole document text rather than a specific
    # element, because unclosed <font> tags in many legacy files make element boundaries
    # meaningless, and we take the *last* occurrence, because the phrase also shows up inside
    # bibliography citations while the date we want is always in the footer. The capture stops at
    # the end of the line (or at a closing bracket) so a mis-parsed document cannot yield a value
    # far longer than a date.
    def extract_date_of_manual_update(html_doc)
      text = html_doc.text
      label_at = text.rindex(LAST_UPDATE_LABEL)
      return nil if label_at.nil?

      date = text[label_at..][LAST_UPDATE_RE, 1].to_s.strip
      # Files where the label is present but the date was never filled in: don't pick up whatever
      # markup happens to follow the label.
      date.match?(/\d/) ? date : nil
    end

    # Extract English title from the header table
    def extract_english_title(html_doc)
      # Look for table cell with dir="ltr" containing the English title
      # The pattern is: <td><p align="center" dir="ltr"><font size="5" color="#FF0000">English Name</font></td>
      english_cell = html_doc.at_css('table td p[dir="ltr"] font[size="5"][color="#FF0000"]')
      english_cell&.text&.squish
    end

    # Extract external identifiers from the footer table
    def extract_external_identifiers(html_doc)
      identifiers = {}

      # Find all table cells with external identifier links
      html_doc.css('table td[dir="ltr"]').each do |cell|
        text = cell.text.strip
        link = cell.at_css('a')
        next unless link

        # Extract identifier type and value based on the text pattern
        case text
        when /^OpenLibrary\s*–\s*/
          identifiers['openlibrary'] = link.text.strip
        when /^Wikidata\s*–\s*/
          identifiers['wikidata'] = link.text.strip
        when /^J9U\s*–\s*/
          identifiers['j9u'] = link.text.strip
        when /^NLI\s*–\s*/
          identifiers['nli'] = link.text.strip
        when /^LC\s*–\s*/
          identifiers['lc'] = link.text.strip
        when /^VIAF\s*–\s*/
          identifiers['viaf'] = link.text.strip
        end
      end

      # J9U is the new-generation NLI ID; prefer it over any legacy NLI value
      identifiers['nli'] = identifiers.delete('j9u') if identifiers.key?('j9u')

      identifiers.presence # Return nil if empty, otherwise return the hash
    end
  end
end
