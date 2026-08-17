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
  # Both the ingestible full-markdown buffer and legacy HtmlFile markdown pack several
  # works into one textarea, separated by these lines. Each work becomes its own document
  # on ingestion, so footnotes may not cross a separator.
  SECTION_SEPARATOR = /\A&&&\s+(.*)/

  # @param markdown [String] the markdown to scan
  # @param split_on_sections [Boolean] treat '&&& title' lines as separate footnote namespaces
  # @return [Hash] :orphan_references and :orphan_bodies, each an array of
  #   { id:, lines: [Integer], section: String or nil }, ordered by first appearance
  def call(markdown, split_on_sections: false)
    orphan_references = []
    orphan_bodies = []

    sections(markdown.to_s, split_on_sections).each do |section|
      references, bodies = scan(section)
      body_ids = bodies.map { |entry| entry[:id] }
      reference_ids = references.map { |entry| entry[:id] }
      orphan_references.concat(references.reject { |entry| body_ids.include?(entry[:id]) })
      orphan_bodies.concat(bodies.reject { |entry| reference_ids.include?(entry[:id]) })
    end

    { orphan_references: group(orphan_references), orphan_bodies: group(orphan_bodies) }
  end

  private

  # Splits the markdown into [title, lines-with-1-based-numbers] pairs. Without
  # split_on_sections there is a single nameless section spanning the whole buffer.
  def sections(markdown, split_on_sections)
    numbered = markdown.lines.each_with_index.map { |line, index| [line, index + 1] }
    return [{ title: nil, lines: numbered }] unless split_on_sections

    result = [{ title: nil, lines: [] }]
    numbered.each do |line, number|
      match = SECTION_SEPARATOR.match(line)
      if match
        result << { title: match[1].strip, lines: [] }
      else
        result.last[:lines] << [line, number]
      end
    end
    result.reject { |section| section[:lines].empty? }
  end

  # Collects every reference and every body in one section. A body line may itself contain
  # references after its marker, so the marker is consumed before scanning the remainder.
  def scan(section)
    references = []
    bodies = []
    section[:lines].each do |line, number|
      rest = line
      body_match = BODY_MARKER.match(line)
      if body_match
        bodies << { id: body_match[1], line: number, section: section[:title] }
        rest = body_match.post_match
      end
      rest.scan(REFERENCE) do |(id)|
        references << { id: id, line: number, section: section[:title] }
      end
    end
    [references, bodies]
  end

  # Collapses repeats of the same identifier within a section into one entry listing all
  # the lines it appears on.
  def group(entries)
    entries.group_by { |entry| [entry[:section], entry[:id]] }
           .map do |(section, id), group|
             { id: id, lines: group.map { |entry| entry[:line] }, section: section }
           end
  end
end
