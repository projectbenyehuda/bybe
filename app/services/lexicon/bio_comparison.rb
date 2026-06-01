# frozen_string_literal: true

module Lexicon
  # Compares the word count of a migrated LexPerson biography against the
  # biography portion of the original legacy PHP file.
  #
  # The legacy bio portion is the prose between the heading table and the
  # "Books" anchor -- the exact region IngestPerson drew the migrated bio from
  # (see Lexicon::IngestPerson#create_lex_item). Both sides are reduced to plain
  # text with HTML tags and punctuation stripped, then tokenised into words so
  # the counts (and an optional side-by-side diff) are an apples-to-apples
  # comparison.
  class BioComparison < ApplicationService
    include HtmlUtils

    # Mirrors Lexicon::IngestPerson::WORKS_HEADER -- the anchor that ends the bio.
    WORKS_HEADER = 'Books'

    # A difference of more than this many words is flagged as a discrepancy.
    WORD_DIFF_TOLERANCE = 2

    # Matches runs of letters/numbers; everything else (punctuation, whitespace,
    # HTML having already been stripped) acts as a separator and is discarded.
    WORD_RE = /[[:alnum:]]+/

    # Holds the tokenised words of both sides and the comparison verdict.
    Result = Struct.new(:legacy_words, :migrated_words, keyword_init: true) do
      def legacy_count
        legacy_words.size
      end

      def migrated_count
        migrated_words.size
      end

      def difference
        (legacy_count - migrated_count).abs
      end

      def discrepancy?
        difference > WORD_DIFF_TOLERANCE
      end
    end

    # @param item [LexPerson] the migrated person whose bio is verified
    # @param source_content [String, nil] the raw legacy PHP HTML
    def call(item, source_content)
      Result.new(
        legacy_words: words_from_html(extract_legacy_bio_html(source_content)),
        migrated_words: words_from_html(MarkdownToHtml.call(item.bio))
      )
    end

    private

    # Extracts the bio HTML from the legacy file by walking siblings of the
    # heading table up to the "Books" header, mirroring the boundary logic in
    # Lexicon::IngestPerson#create_lex_item (including the wrapping-span fallback).
    def extract_legacy_bio_html(source_content)
      return '' if source_content.blank?

      html_doc = Nokogiri::HTML(source_content)
      heading_table = html_doc.at_css('table[width="100%"]')
      return '' if heading_table.nil?

      next_elem = heading_table.next_element
      at_span_level = false
      if next_elem.nil? && heading_table.parent.name == 'span'
        next_elem = heading_table.parent.next_element
        at_span_level = true
      end

      bio, next_elem = collect_bio_until_works(next_elem)

      # Bio was inside the wrapping span but the works header is outside it.
      if next_elem.nil? && !at_span_level && heading_table.parent.name == 'span'
        extra_bio, = collect_bio_until_works(heading_table.parent.next_element)
        bio += extra_bio
      end

      bio.join("\n")
    end

    def collect_bio_until_works(elem)
      bio = []
      while elem.present? && !header?(elem, WORKS_HEADER)
        bio << elem.to_html
        elem = elem.next_element
      end
      [bio, elem]
    end

    def words_from_html(html)
      return [] if html.blank?

      Nokogiri::HTML.fragment(html).text.scan(WORD_RE)
    end
  end
end
