# frozen_string_literal: true

module Lexicon
  # Service to extract title from Lexicon entry
  class ExtractTitle < ApplicationService
    def call(fname)
      html_doc = File.open(fname) { |f| Nokogiri::HTML(f) }

      title_table_node = html_doc.at_css('table#table5')
      if title_table_node.present?
        # first td element with center alignment is the title
        title = title_table_node.at_css('td p[align="center"]')&.text
      end
      title = html_doc.css('title')&.text if title.blank?

      title.strip.gsub('&nbsp;', ' ').squish if title.present?
    end
  end
end
