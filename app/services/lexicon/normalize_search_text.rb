# frozen_string_literal: true

module Lexicon
  # Reduces Hebrew text to the form the lexicon searches on, so that neither punctuation nor
  # pointing can keep a search from finding an entry: "אמונה אלון" has to find "אמונה אֵלון",
  # "בן ציון בן משה" has to find "בן־ציון בן־משה", and "כץ" has to find "כ״ץ".
  #
  # The same table drives both halves of lexicon search, which is the point of collecting it
  # here: the MySQL `LIKE` filters compare against LexEntry#normalized_title, built by #call,
  # while LexEntriesIndex and LexEntriesAutocompleteIndex feed .elasticsearch_mappings to a
  # `mapping` char filter. Were the two to drift, the same query would find different entries
  # on the list page than in site-wide search.
  #
  # This is deliberately not Lexicon::TitleSimilarity's normalization, which maps quotes to a
  # space: that is right when scoring two bibliographic titles against each other, but here it
  # would split "כ״ץ" into two words and leave the search for "כץ" empty-handed.
  class NormalizeSearchText < ApplicationService
    # A maqaf -- or any of the dashes the titles use interchangeably with it -- stands
    # *between* two words, so it becomes a space rather than disappearing: dropping it would
    # turn "בן־ציון" into "בןציון", which a search for "בן ציון" would still miss.
    SEPARATORS = {
      '־' => ' ', # Hebrew maqaf
      '-' => ' ', # hyphen-minus
      '–' => ' ', # en dash
      '—' => ' '  # em dash
    }.freeze

    # Geresh and gershayim, by contrast, sit *inside* a word -- in acronyms ("כ״ץ"), in
    # transliterated sounds ("צ׳יקי") and around nicknames -- so they are dropped, which is
    # what lets "כץ" match "כ״ץ". Their ASCII and curly lookalikes go too, since the legacy
    # files use all of them interchangeably for the same purpose.
    ELISIONS = ['׳', '״', "'", '"', '‘', '’', '“', '”'].freeze

    # Hebrew points and cantillation marks are a typographical choice, not part of a name.
    # The maqaf (U+05BE) is excluded from the range -- it is a separator, handled above.
    #
    # The `hebrew` gem's String#strip_nikkud (used for sort_title) is not enough here: it
    # covers only U+05B0..U+05BC plus the sin/shin dots, leaving meteg, rafe, qamats qatan and
    # the entire cantillation range in place.
    POINTS = ((0x0591..0x05BD).to_a + (0x05BF..0x05C7).to_a).map { |cp| cp.chr(Encoding::UTF_8) }.freeze

    MAPPINGS = SEPARATORS.merge((ELISIONS + POINTS).index_with('')).freeze
    PATTERN = Regexp.union(MAPPINGS.keys).freeze

    # Titles carry Latin script too ("Gail Hareven"), and lex_entries is a utf8mb4_bin table,
    # so the comparison would otherwise be case-sensitive on exactly those entries.
    #
    # @param text [String, nil]
    # @return [String, nil] nil for nil input, so an absent title stays absent rather than ''
    def call(text)
      return nil if text.nil?

      text.gsub(PATTERN, MAPPINGS).squish.downcase
    end

    # The same table in the form Elasticsearch's `mapping` char filter takes. Every character
    # is written as \uXXXX so that the combining marks survive the trip through JSON and the
    # analysis-settings parser as characters in their own right.
    #
    # A `mapping` char filter is used rather than the more compact `pattern_replace` because
    # it corrects offsets as it deletes; pattern_replace does not, which would misplace the
    # highlighted fragments site-wide search draws over :fulltext.
    #
    # @return [Array<String>] e.g. ["\\u05BE=>\\u0020", "\\u05F4=>"]
    def self.elasticsearch_mappings
      MAPPINGS.map { |from, to| "#{escape(from)}=>#{escape(to)}" }
    end

    # @param str [String] may be empty, which escapes to an empty (i.e. deleting) replacement
    def self.escape(str)
      str.each_char.map { |char| format('\\u%04X', char.ord) }.join
    end
    private_class_method :escape
  end
end
