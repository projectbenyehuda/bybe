# frozen_string_literal: true

module Lexicon
  # Service scans HTML page for links to attachments hosted on old lexicon site and
  # - loads them into BYP database
  # - creates LexLegacyLink record to support legacy links re-routing
  # - replaces links in html to lead to new locations
  class ProcessLinks < ApplicationService
    # An href that already names where it points: an absolute or protocol-relative URL, anything
    # carrying a scheme (mailto:, and the file:/javascript: junk a few legacy pages contain), or a
    # path rooted at this site. Everything else is relative to the old lexicon directory.
    ABSOLUTE_HREF_REGEX = %r{\A(/|[a-z][a-z0-9+.-]*:)}i

    # A legacy path we could not resolve means nothing on this site: a browser resolves it against
    # whatever page it is rendered on (e.g. /lex/verification/99995-files/...), which points at
    # nothing at all. Send it back to the old site, where it still means what the source file
    # meant. Hrefs that already name where they point are returned untouched, so this is safe to
    # apply to a value that may or may not need it. Also used by the
    # fix_lexicon_relative_legacy_urls rake task to repair values stored before this was in place.
    def self.absolutize(href)
      return href if href.blank? || href.match?(ABSOLUTE_HREF_REGEX) || href.start_with?('#')

      "#{Lexicon::OLD_LEXICON_URL}/#{href}"
    end

    def call(html_doc, lex_entry)
      html_doc.css('a').each do |tag|
        href = tag['href']

        next if href.blank?

        next if href[0] == '#' # local href (anchor on the same page)

        tag['href'] = new_location(href, lex_entry) || self.class.absolutize(href)
      end
    end

    private

    # The new, on-site location of a legacy href, or nil when it names something we did not
    # migrate (an un-ingested lexicon page, or an attachment we failed to download).
    def new_location(href, lex_entry)
      # Link to lexicon root page should be replaced with a link to the new root page
      return Rails.application.routes.url_helpers.lexicon_root_path if href == 'index.htm'

      # see https://github.com/projectbenyehuda/bybe/issues/1035#issuecomment-3966763191
      return "/lexicon/#{href}" if href.start_with?('hbe/')

      # Checking if this a link to another Lexicon page and if so replacing it with a link to the
      # new location. A page we have not ingested is never offered to MigrateAttachment: it is not
      # an attachment, and the fallback below is the only thing left to do with it.
      match = href.match(/\A(?<filename>\d+\.php)(?:#(?<anchor>.*))?\z/)
      return lexicon_entry_href(match) if match.present?

      MigrateAttachment.call(href, lex_entry).presence
    end

    def lexicon_entry_href(match)
      entry = LexFile.find_by(fname: match[:filename])&.lex_entry
      return nil if entry.nil?

      new_path = Rails.application.routes.url_helpers.lexicon_entry_path(entry)
      anchor = match[:anchor]
      anchor.present? ? "#{new_path}##{anchor}" : new_path
    end
  end
end
