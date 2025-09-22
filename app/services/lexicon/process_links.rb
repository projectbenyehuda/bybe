# frozen_string_literal: true

module Lexicon
  # Service scans HTML page for links to attachments hosted on old lexicon site and
  # - loads them into BYP database
  # - creates LexLegacyLink record to support legacy links re-routing
  # - replaces links in html to lead to new locations
  class ProcessLinks < ApplicationService
    def call(html_doc, lex_entry)
      html_doc.css('a').each do |tag|
        href = tag['href']

        next if href.blank?

        next if href[0] == '#' # local href

        new_path = MigrateAttachment.call(href, lex_entry)
        if new_path.present?
          tag['href'] = new_path
        end
      end
    end
  end
end
