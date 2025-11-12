# frozen_string_literal: true

# Service to prepare HTML with chapter navigation for a manifestation
# Extracts chapter headings, annotates them with anchors, and generates navigation data
class ManifestationHtmlWithChapters < ApplicationService
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::SanitizeHelper

  # @param manifestation [Manifestation] The manifestation to process
  # @return [Hash] Contains :html, :chapters, and :selected_chapter
  def call(manifestation)
    lines = manifestation.markdown.lines
    tmphash = {}
    chapters = [] # TODO: add sub-chapters, indenting two nbsps in dropdown

    ch_count = 0
    # annotate headings in reverse order, to avoid offsetting the next heading
    manifestation.heading_lines.reverse.each do |linenum|
      ch_count += 1
      insert_text = "<a name=\"ch#{linenum}\" class=\"ch_anch\" id=\"ch#{linenum}\">&nbsp;</a>\r\n"
      lines.insert(linenum, insert_text)
      tmphash[ch_count.to_s.rjust(4, '0') + SanitizeHeading.call(lines[linenum + 1][2..].strip)] = linenum.to_s
    end
    tmphash.keys.reverse.map { |k| chapters << [k[4..], tmphash[k]] }
    selected_chapter = tmphash.keys.last

    html = MarkdownToHtml.call(lines.join)
    html = MakeHeadingIdsUnique.call(html)

    # add permalinks
    permalink_base_url = manifestation_url(manifestation)
    html.gsub!(%r{<h2(.*?) id="(.*?)"(.*?)>(.*?)</h2>},
               '<h2\\1 id="\\2"\\3>\\4 &nbsp;&nbsp; ' \
               "<span style=\"font-size: 50%;\"><a title=\"#{I18n.t(:permalink)}\" " \
               "href=\"#{permalink_base_url}#\\2\">🔗</a></span></h2>")
    html.gsub!(%r{<h3(.*?) id="(.*?)"(.*?)>(.*?)</h3>},
               '<h3\\1 id="\\2"\\3>\\4 &nbsp;&nbsp; ' \
               "<span style=\"font-size: 50%;\"><a title=\"#{I18n.t(:permalink)}\" " \
               "href=\"#{permalink_base_url}#\\2\">🔗</a></span></h3>")

    {
      html: html,
      chapters: chapters,
      selected_chapter: selected_chapter
    }
  end
end
