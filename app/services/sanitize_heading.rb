# frozen_string_literal: true

# Service to sanitize heading text for use in navigation or display
# Removes footnotes, strips HTML tags, replaces leading hashes with spaces, and cleans up quotes.
# Note: strip_tags HTML-escapes quotes in its output (" -> &quot;, ' -> &#39;), so the result is HTML.
class SanitizeHeading < ApplicationService
  include ActionView::Helpers::SanitizeHelper

  # @param heading [String] Raw heading text that may contain HTML, footnotes, etc.
  # @return [String] Sanitized heading text
  def call(heading)
    # Remove footnotes, unescape markdown escapes (incl. quotes) BEFORE strip_tags, which HTML-escapes quotes
    heading.gsub(/\[\^ftn\d+\]/, '')
           .gsub(/\[\^\d+\]/, '')
           .gsub(/\\([<>])/) { |match| CGI.escapeHTML(match[1]) } # Unescape and HTML-escape angled brackets
           .gsub(/\\([\[\]\*\_\{\}\(\)\#\+\-\.\!'"])/, '\1') # Remove markdown escape backslashes for other characters
           .then { |s| strip_tags(s) }
           .gsub(/^#+/, '&nbsp;&nbsp;&nbsp;')
           .strip
  end
end
