# frozen_string_literal: true

module Lexicon
  # Base class for php file ingestion
  class IngestBase < ApplicationService
    def call(lex_file)
      lex_entry = lex_file.lex_entry

      html_doc = File.open(lex_file.full_path) { |f| Nokogiri::HTML(f) }
      Lexicon::AttachImages.call(html_doc, lex_entry)
      Lexicon::ProcessLinks.call(html_doc, lex_entry)

      lex_entry.lex_item = create_lex_item(html_doc)
      lex_entry.english_title = extract_english_title(html_doc)
      lex_entry.external_identifiers = extract_external_identifiers(html_doc)
      lex_entry.status_draft!

      lex_file.status_ingested!
      lex_entry
    end

    def create_lex_item(_html_doc)
      raise('Not implemented')
    end

    private

    # Extract English title from the header table
    def extract_english_title(html_doc)
      # Look for table cell with dir="ltr" containing the English title
      # The pattern is: <td><p align="center" dir="ltr"><font size="5" color="#FF0000">English Name</font></td>
      english_cell = html_doc.at_css('table td p[dir="ltr"] font[size="5"][color="#FF0000"]')
      english_cell&.text&.strip
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

      identifiers.presence # Return nil if empty, otherwise return the hash
    end
  end
end
