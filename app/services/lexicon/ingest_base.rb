# frozen_string_literal: true

module Lexicon
  # Base class for php file ingestion
  class IngestBase < ApplicationService
    LAST_UPDATE_LABEL = 'עודכן לאחרונה'
    LAST_UPDATE_RE = /#{LAST_UPDATE_LABEL}:?\s*([^\]\r\n]*)/
    LATIN_SCRIPT_RE = /\p{Latin}/
    # Letters only: the Hebrew block also holds geresh and gershayim, which the legacy files use as
    # apostrophes inside transliterated English names ("Ya׳akov Rabinowitz").
    HEBREW_LETTER_RE = /[\p{Hebrew}&&\p{L}]/
    BOM = "\uFEFF"

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

    # Extract English title from the header table.
    #
    # The name lives in a cell of the very first table, next to the Hebrew one, but the legacy
    # files are wildly inconsistent about how they mark it: font size 4 or 5, red or blue, the
    # dir="ltr" attribute on the <p>, on the <td> or missing altogether, and the name itself often
    # broken across nested <span lang="en-us"> elements or an early-closing <font>. So we take the
    # whole cell's text instead of matching one specific font tag.
    #
    # Choosing the cell: prefer the ones explicitly marked ltr, and fall back to every cell when
    # none is. Among those we take the first written in Latin script and free of Hebrew letters,
    # which skips the Hebrew title cell and, in the handful of entries that also show the name in
    # its original script, the Cyrillic/Hungarian cell that precedes the English one.
    def extract_english_title(html_doc)
      header_table = html_doc.at_css('table')
      return nil if header_table.nil?

      cells = header_table.css('td')
      ltr_cells = cells.select { |cell| cell['dir'] == 'ltr' || cell.at_css('[dir="ltr"]') }
      english_cell = (ltr_cells.presence || cells).find do |cell|
        text = cell.text
        text.match?(LATIN_SCRIPT_RE) && !text.match?(HEBREW_LETTER_RE)
      end
      return nil if english_cell.nil?

      # A few files start the cell with a byte order mark, which squish does not consider space.
      english_cell.text.delete(BOM).squish.presence
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
