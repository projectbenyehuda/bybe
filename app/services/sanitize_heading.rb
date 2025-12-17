# frozen_string_literal: true

# Service to sanitize heading text for use in navigation or display
# Removes footnotes, strips HTML tags, replaces leading hashes with spaces, and cleans up quotes
class SanitizeHeading < ApplicationService
  include ActionView::Helpers::SanitizeHelper

  # @param heading [String] Raw heading text that may contain HTML, footnotes, etc.
  # @return [String] Sanitized heading text
  def call(heading)
    # Remove footnotes, strip HTML tags, replace leading hashes with spaces, and clean up quotes
    heading.gsub(/\[\^ftn\d+\]/, '')
           .gsub(/\[\^\d+\]/, '')
           .gsub(/\\([<>])/) { |match| CGI.escapeHTML(match[1]) } # Unescape and HTML-escape angled brackets
           .gsub(/\\([\[\]\*\_\{\}\(\)\#\+\-\.\!'])/, '\1') # Remove markdown escape backslashes for other characters
           .then { |s| strip_tags(s) }
           .gsub(/^#+/, '&nbsp;&nbsp;&nbsp;')
           .gsub('\"', '"')
           .strip
  end
end
