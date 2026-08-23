# frozen_string_literal: true

# Scans a Hebrew text's MultiMarkdown for the shapes a scanning/OCR/typing slip usually takes,
# so that Manifestation.update_suspected_typos_list can queue the texts worth a human look.
# Every check here is a heuristic: it produces candidates, not verdicts, which is why the
# report that consumes it offers editors a "this is fine" whitelist.
#
# The four checks are the ones enumerated in the original TODO:
#   :digit_in_word          - a digit welded onto a Hebrew letter, the classic OCR slip
#   :final_mid_word         - a final letter with more word after it
#   :nonfinal_at_word_end   - a word ending in a letter whose final form belongs there
#   :unterminated_paragraph - a prose paragraph that just stops, with no terminal punctuation
#
# The character-class constants below carry their codepoints in comments: a bracket
# expression mixing RTL letters with '-' and ']' renders in a confusing order in an LTR
# editor, and a mis-ordered range is accepted by Ruby without complaint.
class DetectSuspectedTypos < ApplicationService
  # Hebrew consonants, alef (U+05D0) through tav (U+05EA). Deliberately not \p{Hebrew}, which
  # also matches the points and cantillation marks we want to treat as invisible.
  LETTER = 'א-ת'
  # Nikkud, dagesh and cantillation - all non-spacing marks. These sit *between* a letter and
  # whatever follows it, so every adjacency test has to step over them. Matched by category
  # rather than by codepoint range: the Hebrew block interleaves its marks with punctuation
  # (U+05BE maqaf, U+05C0 paseq, U+05C3 sof pasuq), and swallowing the maqaf would make
  # "ה־1948" look like a digit glued to a letter.
  POINT = '\p{Mn}'
  # kaf, mem, nun, pe, tsadi sofit
  FINALS = 'ךםןףץ'
  # The same letters in their ordinary form; one of these ending a word is suspect. Pe is
  # deliberately absent: final pe is /f/, so a loanword ending in /p/ correctly keeps the
  # ordinary form (קטשופ, טלסקופ, ג'יפ), and including it made this the noisiest check by far.
  NEEDS_FINAL = 'כמנצ'
  # Geresh and gershayim, in both their Hebrew-block (U+05F3/U+05F4) and ASCII-typed
  # spellings. Between letters they mark an acronym, at the end an abbreviation - in both
  # cases a non-final ending is correct and must not be reported.
  GERESH = "'\"׳״"

  DIGIT_IN_WORD = /[#{LETTER}][#{POINT}]*\d|\d[#{LETTER}]/o
  # A word, including any internal or trailing geresh, so that acronyms and abbreviations
  # arrive intact and can be recognised as such.
  WORD = /[#{LETTER}][#{LETTER}#{POINT}#{GERESH}]*/o
  # A cheap superset of the two word-level checks, used to skip the ~95% of words that cannot
  # possibly match before doing the allocating work of stripping points and quote characters.
  # The whole corpus is scanned weekly, so the saving is worth the duplication.
  CANDIDATE_WORD = /[#{FINALS}][#{POINT}]*[#{LETTER}]|[#{NEEDS_FINAL}][#{POINT}#{GERESH}]*\z/o
  POINTS_ONLY = /[#{POINT}]/o
  SURROUNDING_GERESH = /\A[#{GERESH}]+|[#{GERESH}]+\z/o
  ANY_GERESH = /[#{GERESH}]/o
  # A *single* geresh closing a word marks an abbreviation. Gershayim is deliberately not
  # here: a word is scanned from its first letter, so a leading quotation mark is not part of
  # the token and a trailing '"' is far more often the closing half of a quoted word than an
  # abbreviation mark - acronyms carry their gershayim before the last letter, not after it.
  ABBREVIATION_MARK = /['׳]\z/

  # Genres whose paragraphs are expected to be sentences. Poetry and drama are line-broken by
  # nature, and letters/reference/lexicon end on signatures, datelines and headword
  # fragments, so for all of those an unterminated paragraph is the norm, not a defect.
  PROSE_GENRES = %w(prose article memoir fables).freeze
  # Below this a "paragraph" is more likely a heading, a dateline or a signature than a
  # sentence that lost its full stop.
  MIN_PROSE_PARAGRAPH_LENGTH = 80
  # A paragraph is reported only when it ends on a bare letter. Anything else - a comma, a
  # dash, an ellipsis, a colon - is either terminal punctuation or a deliberate continuation,
  # and in the corpus the punctuated cases were almost all correct.
  UNTERMINATED_END = /[#{LETTER}][#{POINT}]*\z/o
  # Stripped from the end of a paragraph first: closing quotes and brackets, and the emphasis
  # markers that wrap the punctuation rather than replace it.
  TRAILING_DECORATION = "*_\"'”’»)›]}׳״"
  TRAILING_DECORATION_RE = /[#{Regexp.escape(TRAILING_DECORATION)}\s]+\z/o
  FOOTNOTE_MARKER = /\[\^[^\]\n]+\]/
  FOOTNOTE_REFERENCE = /#{FOOTNOTE_MARKER}\z/o
  # Markup that is not prose and must not be judged as such: footnote identifiers, whole
  # images (their alt text is a filename), and the target of any link.
  MASKED_MARKUP = /!\[[^\]\n]*\]\([^)\n]*\)|#{FOOTNOTE_MARKER}|\]\([^)\n]*\)/o
  # A word cut short by an adjacent dash or ellipsis is deliberate - stammering, an
  # interruption, a hyphenated compound - not a missing final letter.
  TRUNCATION_MARK = /\A(?:[-־–—]|\.{2,}|…)/
  # Presentation forms (U+FB1D..U+FB4F) spell a pointed letter as one codepoint, so a word
  # containing one would be cut in half by the letter-plus-marks scanning below. They carry a
  # canonical decomposition, so normalizing restores the ordinary letter-plus-mark spelling.
  PRESENTATION_FORM = /[יִ-ﭏ]/
  # Lines that are markup rather than prose: headings, quotes, lists, tables, footnote
  # bodies, horizontal rules, raw HTML, images and the '&&&' work separator. A paragraph
  # containing any of these is not a sentence and is not judged as one.
  MARKUP_LINE = /\A(?: {0,3}(?:[#>|*+-]|\d+[.)]|\[\^|&&&|!\[|<)| {4,}\S)/
  LINE_ENDING = /\r\n?/

  # Reporting every hit in a badly-OCRed text would bury the report without telling an editor
  # anything the first few hits did not.
  MAX_FINDINGS_PER_TYPE = 20
  # How much context to show around a character-level hit.
  CONTEXT_CHARS = 30

  # @param markdown [String] the text to scan
  # @param genre [String, nil] the work's genre; only prose genres get the paragraph check
  # @return [Array<Hash>] findings, each { type: Symbol, line: Integer, match: String,
  #   text: String } - the offending fragment and the surrounding context - grouped by type
  #   in the order the checks are declared above, then by line
  def call(markdown, genre = nil)
    text = markdown.to_s
    return [] if text.blank?

    text = text.gsub(LINE_ENDING, "\n") if text.include?("\r")
    text = text.unicode_normalize if text.match?(PRESENTATION_FORM)
    lines = text.lines

    findings = scan_lines(lines)
    findings += scan_paragraphs(lines) if PROSE_GENRES.include?(genre)
    findings
  end

  private

  # The three character-level checks, all of which are decided within a single line.
  def scan_lines(lines)
    digits = []
    finals_mid = []
    nonfinal_ends = []

    lines.each_with_index do |raw_line, index|
      line_no = index + 1
      line = mask_markup(raw_line)
      line.scan(DIGIT_IN_WORD) do
        digits << finding(:digit_in_word, line_no, line, Regexp.last_match)
      end
      line.scan(WORD) do |word|
        next unless word.match?(CANDIDATE_WORD)

        # String#match? leaves $~ alone, so this is still the scan's own match. It has to be
        # read before letters_of, whose gsub would overwrite it.
        match = Regexp.last_match
        letters = letters_of(word)
        next if letters.nil? || letters.length < 2

        finals_mid << finding(:final_mid_word, line_no, line, match) if final_mid_word?(letters)
        if NEEDS_FINAL.include?(letters[-1]) && !truncated?(line, match.end(0))
          nonfinal_ends << finding(:nonfinal_at_word_end, line_no, line, match)
        end
      end
    end

    cap(digits) + cap(finals_mid) + cap(nonfinal_ends)
  end

  # A footnote id like '[^ftn1א]' and an image filename like 'תמונה155-156.png' mix digits and
  # Hebrew letters by design, and together were the largest source of spurious
  # :digit_in_word hits. Blanked out rather than deleted, so that the offsets used for
  # context stay in step with the line.
  def mask_markup(line)
    return line unless line.include?('[')

    line.gsub(MASKED_MARKUP) { |markup| ' ' * markup.length }
  end

  def truncated?(line, offset)
    line[offset..].to_s.match?(TRUNCATION_MARK)
  end

  # The bare consonants of a word, or nil when the word is an acronym or abbreviation, where
  # a non-final ending and a mid-word final are both correct. A geresh still present after
  # the surrounding quote characters are stripped is internal, and marks an acronym.
  def letters_of(word)
    return nil if word.match?(ABBREVIATION_MARK)

    core = word.gsub(SURROUNDING_GERESH, '')
    return nil if core.match?(ANY_GERESH)

    core.gsub(POINTS_ONLY, '')
  end

  def final_mid_word?(letters)
    letters[0..-2].each_char.any? { |c| FINALS.include?(c) }
  end

  # Blank-line-separated blocks of prose that stop without terminal punctuation.
  def scan_paragraphs(lines)
    findings = []
    each_paragraph(lines) do |paragraph_lines, last_line_no|
      next if paragraph_lines.any? { |l| l.match?(MARKUP_LINE) }

      paragraph = paragraph_lines.join.strip
      next if paragraph.length < MIN_PROSE_PARAGRAPH_LENGTH

      ending = unterminated_ending(paragraph)
      next if ending.nil?

      findings << { type: :unterminated_paragraph, line: last_line_no, match: ending,
                    text: tail(paragraph) }
    end
    cap(findings)
  end

  def each_paragraph(lines)
    current = []
    lines.each_with_index do |line, index|
      if line.strip.empty?
        yield(current, index) unless current.empty? # index is the 1-based number of the line before
        current = []
      else
        current << line
      end
    end
    yield(current, lines.length) unless current.empty?
  end

  # The bare letter a paragraph ends on, or nil when it ends on punctuation of any kind.
  def unterminated_ending(paragraph)
    stripped = paragraph.sub(FOOTNOTE_REFERENCE, '').gsub(TRAILING_DECORATION_RE, '')
    stripped[UNTERMINATED_END]
  end

  def finding(type, line_no, line, match)
    from = [match.begin(0) - CONTEXT_CHARS, 0].max
    context = line[from...[match.end(0) + CONTEXT_CHARS, line.length].min]
    { type: type, line: line_no, match: match[0], text: context.strip }
  end

  def tail(paragraph)
    paragraph.length > CONTEXT_CHARS * 2 ? "…#{paragraph[-(CONTEXT_CHARS * 2)..]}" : paragraph
  end

  def cap(findings)
    findings.first(MAX_FINDINGS_PER_TYPE)
  end
end
