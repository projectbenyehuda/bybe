# frozen_string_literal: true

# Scans MultiMarkdown for footnote references ([^id] anywhere) and footnote bodies
# ([^id]: at the beginning of a line) and reports the ones that have no counterpart.
#
# Editors only find out about a mismatched footnote once the text is rendered, where a
# stray reference silently disappears and a stray body shows up as literal text. This
# service lets the markdown-editing screens flag the problem while it is still cheap to fix.
class DetectFootnoteDiscrepancies < ApplicationService
  # MMD tolerates up to three leading spaces before a block-level marker.
  BODY_MARKER = /\A {0,3}\[\^([^\]\n]+)\]:/
  REFERENCE = /\[\^([^\]\n]+)\]/
  # Both the ingestible full-markdown buffer and legacy HtmlFile markdown pack several works
  # into one textarea, separated by these lines. A body is NOT required to sit in the same
  # section as its reference: the docx conversion piles every footnote body at the very
  # bottom of the buffer, and Ingestible#relocate_footnotes (HtmlFile#split_parts for the
  # legacy path) only distributes them among the works when the buffer is split. So the
  # section is recorded to say where an orphan is, never to decide whether it is one.
  SECTION_SEPARATOR = /\A&&&\s+(.*)/
  # Markdown reaching us from legacy files and from pastes can carry CRLF or bare-CR line
  # endings. String#lines only splits on LF, so a bare-CR buffer would look like a single
  # line: nothing would match the anchored BODY_MARKER and every reference in the text would
  # be reported as orphaned, even though MultiMarkdown normalizes the endings and renders the
  # footnotes fine. Normalizing also keeps the reported line numbers in step with the textarea
  # the report links into, since the browser presents a bare-CR value as LF-separated lines.
  LINE_ENDING = /\r\n?/

  # @param markdown [String] the markdown to scan
  # @return [Hash] :orphan_references and :orphan_bodies, each an array of
  #   { id:, lines: [Integer], section: String or nil }, ordered by first appearance
  def call(markdown)
    references, bodies = scan(normalize_line_endings(markdown.to_s))
    # sets, not arrays: a text can carry hundreds of footnotes, and this runs on every
    # render of an editing screen
    body_ids = bodies.to_set { |entry| entry[:id] }
    reference_ids = references.to_set { |entry| entry[:id] }

    { orphan_references: group(references.reject { |entry| body_ids.include?(entry[:id]) }),
      orphan_bodies: group(bodies.reject { |entry| reference_ids.include?(entry[:id]) }) }
  end

  private

  # Rewriting the buffer is skipped when there is nothing to rewrite: this runs on every
  # render of an editing screen, where the buffer is usually LF-only already and large enough
  # (a few hundred KB) for a needless full-string copy to cost several milliseconds.
  def normalize_line_endings(markdown)
    markdown.include?("\r") ? markdown.gsub(LINE_ENDING, "\n") : markdown
  end

  # Collects every reference and every body, tagged with the '&&&' section it falls in (nil
  # for a buffer holding a single work) and its 1-based line number in the whole buffer. A
  # body line may itself contain references after its marker, so the marker is consumed
  # before scanning the remainder.
  def scan(markdown)
    references = []
    bodies = []
    section = nil

    markdown.lines.each_with_index do |line, index|
      separator = SECTION_SEPARATOR.match(line)
      if separator
        section = separator[1].strip
        next
      end

      rest = line
      body_match = BODY_MARKER.match(line)
      if body_match
        bodies << { id: body_match[1], line: index + 1, section: section }
        rest = body_match.post_match
      end
      rest.scan(REFERENCE) do |(id)|
        references << { id: id, line: index + 1, section: section }
      end
    end

    [references, bodies]
  end

  # Collapses repeats of the same identifier within a section into one entry listing all
  # the lines it appears on. Lines are deduped, since the same id can appear twice on one
  # line (e.g. '[^1][^1]') and reporting it twice would be noise.
  def group(entries)
    entries.group_by { |entry| [entry[:section], entry[:id]] }
           .map do |(section, id), group|
             { id: id, lines: group.map { |entry| entry[:line] }.uniq, section: section }
           end
  end
end
