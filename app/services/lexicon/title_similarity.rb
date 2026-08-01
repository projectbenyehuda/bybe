# frozen_string_literal: true

module Lexicon
  # Scores how likely two bibliographic titles are to denote the same book, on a 0..100 scale.
  #
  # The legacy lexicon and the BYP bibliography describe the same book with different
  # punctuation and with a different amount of subtitle, e.g.
  #   "בלוק 23 : מכתבים מנס ציונה"  vs  "בלוק 23 ; מכתבים מנס ציונה : נובלות"
  # so both titles are first reduced to their bare words, and then compared in two ways:
  # character-wise, which catches typos and spelling variants, and word-wise, which catches
  # an added subtitle or reordered words. The more forgiving of the two scores wins, since
  # every proposal is confirmed by a human before anything is persisted.
  class TitleSimilarity < ApplicationService
    # Bibliographic separators carry no meaning for matching: the two databases punctuate
    # the very same book differently (": " vs "; ", parentheses, dashes, quotes). The maqaf
    # belongs here rather than with the points below, since it stands between two words.
    SEPARATORS = %r{[-–—־/\\:;,.()\[\]"'״׳]+}

    # Hebrew points and cantillation marks are a typographical choice, not part of the title:
    # "הֵלֵּבָּן" and "הלבן" are the same book. The maqaf (05BE) is excluded -- it is a separator.
    POINTS = /[\u0591-\u05BD\u05BF-\u05C7]/

    # In catalogue records " / " introduces the statement of responsibility -- the author,
    # translator and editor credits, which are not part of the title and which the two
    # databases spell out to a different extent ("חמור הזהב / לוקיוס אפוליאוס").
    STATEMENT_OF_RESPONSIBILITY = %r{\s/.*\z}m

    # Everything that is not a letter or a digit separates words.
    WORD_RE = /[[:alnum:]]+/

    # Below this score two titles are not similar enough to be worth an editor's attention.
    MATCH_THRESHOLD = 70

    # @param title_a [String]
    # @param title_b [String]
    # @param ignoring [String, nil] a name (usually the authority's) that appears in one of the
    #   titles as an attribution rather than as part of the title itself
    # @return [Integer] 0 (nothing in common) .. 100 (identical once normalized)
    def call(title_a, title_b, ignoring: nil)
      a = normalize(title_a, ignoring)
      b = normalize(title_b, ignoring)
      return 0 if a.blank? || b.blank?
      return 100 if a == b

      [character_similarity(a, b), word_similarity(a, b)].max
    end

    private

    # Drops the points, the credits, the given name and all bibliographic punctuation, and
    # lowercases what is left, so that only the words of the title take part in the comparison.
    def normalize(title, ignoring = nil)
      normalized = title.to_s.gsub(POINTS, '')
      # The name goes first: the lexicon writes "name / title" where the bibliography writes
      # "title / name", so dropping it settles which side of the slash the title is on.
      name = ignoring.to_s.gsub(POINTS, '')
      normalized = normalized.gsub(/#{Regexp.escape(name)}/i, '') if name.present?
      # Keep the credits when they are all that is left, rather than comparing against nothing
      without_credits = normalized.sub(STATEMENT_OF_RESPONSIBILITY, '')
      normalized = without_credits if without_credits.present?
      normalized.gsub(SEPARATORS, ' ').squish.downcase
    end

    # Damerau-Levenshtein distance relative to the length of the longer title: a fixed number
    # of edits weighs less the longer the titles are, which is what we want for titles that
    # differ only by a trailing subtitle.
    #
    # The gem gives up past its max_distance argument (10 by default!) and reports that bound
    # instead of the real distance, which would read as near-identity for long titles -- so we
    # pass the one bound an edit distance can never exceed.
    def character_similarity(str_a, str_b)
      longest = [str_a.length, str_b.length].max
      return 0 if longest.zero?

      distance = DamerauLevenshtein.distance(str_a, str_b, 1, longest)
      ((1 - (distance / longest.to_f)) * 100).round.clamp(0, 100)
    end

    # Jaccard index over the words of both titles: insensitive to word order, and to a subtitle
    # present on one side only, while still penalising titles that share just a word or two.
    def word_similarity(str_a, str_b)
      words_a = str_a.scan(WORD_RE).to_set
      words_b = str_b.scan(WORD_RE).to_set
      union = words_a | words_b
      return 0 if union.empty?

      ((words_a & words_b).size / union.size.to_f * 100).round
    end
  end
end
