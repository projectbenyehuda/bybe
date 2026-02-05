# frozen_string_literal: true

# Service to detect and extract a standalone footnote reference at the beginning of markdown
# Used when titles contain footnotes that must be displayed next to the title
class ExtractFirstFootnoteReference < ApplicationService
  # @param markdown [String] The markdown text
  # @param html [String] The rendered HTML from the markdown
  # @return [Hash] Contains :footnote_html (the extracted link or nil) and :cleaned_html (HTML without the footnote ref)
  def call(markdown, html)
    # Check if the first non-whitespace line is ONLY a footnote reference
    first_line = markdown.lines.find { |line| line.strip.present? }
    return { footnote_html: nil, cleaned_html: html } if first_line.blank?

    # Match footnote reference: [^identifier] where identifier can be alphanumeric
    match = first_line.strip.match(/^\[\^([^\]]+)\]\s*$/)
    return { footnote_html: nil, cleaned_html: html } if match.nil?

    # We found a standalone footnote reference at the beginning
    # Now we need to extract the corresponding HTML link from the rendered HTML
    # MultiMarkdown generates: <a href="#fn:N" id="fnref:N" class="footnote"><sup>N</sup></a>
    # where N is the sequential footnote number (starting from 1)

    # Find the first footnote link that appears at the start of a paragraph
    # It may or may not have additional content after it in the same paragraph
    footnote_link_pattern = %r{<p>\s*(<a[^>]*href="#fn:\d+"[^>]*id="fnref:\d+"[^>]*>.*?</a>)}m
    html_match = html.match(footnote_link_pattern)

    if html_match
      footnote_html = html_match[1] # Extract just the <a> tag

      # Remove just the footnote link from the HTML
      cleaned_html = html.sub(footnote_html, '')

      # Clean up any empty paragraphs that may result from the removal
      cleaned_html = cleaned_html.gsub(%r{<p>\s*</p>}, '').strip

      { footnote_html: footnote_html, cleaned_html: cleaned_html }
    else
      # Couldn't find the footnote link in HTML, return original
      { footnote_html: nil, cleaned_html: html }
    end
  end
end
