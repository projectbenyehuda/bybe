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

    # Extracts the bio HTML from the legacy file using the same boundary logic the migration
    # itself uses (HtmlUtils#bio_elements), so the two sides of the comparison always agree on
    # where the biography ends.
    def extract_legacy_bio_html(source_content)
      return '' if source_content.blank?

      heading_table = Nokogiri::HTML(source_content).at_css('table[width="100%"]')
      return '' if heading_table.nil?

      bio_elements(heading_table).map(&:to_html).join("\n")
    end

    def words_from_html(html)
      return [] if html.blank?

      Nokogiri::HTML.fragment(html).text.scan(WORD_RE)
    end
  end
end
