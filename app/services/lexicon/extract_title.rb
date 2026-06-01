# frozen_string_literal: true

module Lexicon
  # Service to extract title from Lexicon entry
  class ExtractTitle < ApplicationService
    # Matches trailing life years in parentheses: (YYYY) or (YYYY─YYYY)
    # Handles Hebrew maqaf (U+05BE), en-dash (U+2013), and regular hyphen.
    LIFE_YEARS_PATTERN = /\s*\(\d{4}(?:[-–־]\d{4})?\)\s*\z/

    def call(fname)
      html_doc = File.open(fname) { |f| Nokogiri::HTML(f) }

      title_table_node = html_doc.at_css('table#table5')
      if title_table_node.present?
        # first td element with center alignment is the title
        title = title_table_node.at_css('td p[align="center"]')&.text
      end
      title = html_doc.css('title')&.text if title.blank?

      title.strip.gsub('&nbsp;', ' ').squish.sub(LIFE_YEARS_PATTERN, '') if title.present?
    end
  end
end
