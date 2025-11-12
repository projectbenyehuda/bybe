# frozen_string_literal: true

# Service to prepare HTML with chapter navigation for a manifestation
# Extracts chapter headings, annotates them with anchors, and generates navigation data
class ManifestationHtmlWithChapters < ApplicationService
  include ActionView::Helpers::SanitizeHelper

  # @param manifestation [Manifestation] The manifestation to process
  # @param permalink_base_url [String] Base URL for generating chapter permalinks
  # @return [Hash] Contains :html, :chapters, and :selected_chapter
  def call(manifestation, permalink_base_url)
    lines = manifestation.markdown.lines
    tmphash = {}
    chapters = [] # TODO: add sub-chapters, indenting two nbsps in dropdown

    ch_count = 0
    # annotate headings in reverse order, to avoid offsetting the next heading
    manifestation.heading_lines.reverse.each do |linenum|
      ch_count += 1
      insert_text = "<a name=\"ch#{linenum}\" class=\"ch_anch\" id=\"ch#{linenum}\">&nbsp;</a>\r\n"
      lines.insert(linenum, insert_text)
      tmphash[ch_count.to_s.rjust(4, '0') + sanitize_heading(lines[linenum + 1][2..-1].strip)] = linenum.to_s
    end
    tmphash.keys.reverse.map { |k| chapters << [k[4..], tmphash[k]] }
    selected_chapter = tmphash.keys.last

    html = MarkdownToHtml.call(lines.join(''))
    # Replace MultiMarkdown-generated ids with unique sequential ids to avoid duplicates
    html = make_heading_ids_unique(html)

    # add permalinks
    html.gsub!(%r{<h2(.*?) id="(.*?)"(.*?)>(.*?)</h2>},
               "<h2\\1 id=\"\\2\"\\3>\\4 &nbsp;&nbsp; <span style=\"font-size: 50%;\"><a title=\"קישור קבוע\" href=\"#{permalink_base_url}#\\2\">🔗</a></span></h2>")
    html.gsub!(%r{<h3(.*?) id="(.*?)"(.*?)>(.*?)</h3>},
               "<h3\\1 id=\"\\2\"\\3>\\4 &nbsp;&nbsp; <span style=\"font-size: 50%;\"><a title=\"קישור קבוע\" href=\"#{permalink_base_url}#\\2\">🔗</a></span></h3>")

    {
      html: html,
      chapters: chapters,
      selected_chapter: selected_chapter
    }
  end

  private

  def sanitize_heading(h)
    # Remove footnotes, strip HTML tags, replace leading hashes with spaces, and clean up quotes
    h.gsub(/\[\^ftn\d+\]/, '')
     .gsub(/\[\^\d+\]/, '')
     .then { |s| strip_tags(s) }
     .gsub(/^#+/, '&nbsp;&nbsp;&nbsp;')
     .gsub('\"', '"')
     .strip
  end

  def make_heading_ids_unique(html)
    # Replace MultiMarkdown-generated ids with unique sequential ids to avoid duplicates
    heading_seq = 0
    html.gsub(%r{<(h[23])(.*?) id="(.*?)"(.*?)>(.*?)</\1>}) do
      heading_seq += 1
      tag = ::Regexp.last_match(1)
      "<#{tag}#{::Regexp.last_match(2)} id=\"heading-#{heading_seq}\"#{::Regexp.last_match(4)}>#{::Regexp.last_match(5)}</#{tag}>"
    end
  end
end
