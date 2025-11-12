# frozen_string_literal: true

# Service to replace MultiMarkdown-generated heading IDs with unique sequential IDs
# This prevents duplicate ID issues when headings with the same text appear multiple times
class MakeHeadingIdsUnique < ApplicationService
  # @param html [String] HTML content with headings
  # @return [String] HTML with unique sequential heading IDs
  def call(html)
    # Replace MultiMarkdown-generated ids with unique sequential ids to avoid duplicates
    heading_seq = 0
    html.gsub(%r{<(h[23])(.*?) id="(.*?)"(.*?)>(.*?)</\1>}) do
      heading_seq += 1
      tag = ::Regexp.last_match(1)
      "<#{tag}#{::Regexp.last_match(2)} id=\"heading-#{heading_seq}\"#{::Regexp.last_match(4)}>#{::Regexp.last_match(5)}</#{tag}>"
    end
  end
end
