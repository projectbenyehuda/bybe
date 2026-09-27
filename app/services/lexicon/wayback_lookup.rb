# frozen_string_literal: true

module Lexicon
  # Finds the most recent working (HTTP 200) snapshot of a URL in the Internet Archive's Wayback
  # Machine, so a verifier can replace a dead link with its archived copy instead of hunting for one.
  # Neither API used needs a key.
  #
  # Asks the Availability API first: it answers in a second or two, but misses plenty of archived
  # URLs -- in testing it came back empty for https://benyehuda.org/lexicon/00001.php yet found the
  # same page without the scheme, and found www.haaretz.co.il/literature only *with* the www.
  # When it has nothing, falls back to the CDX API, which is authoritative but routinely takes
  # 10-60 seconds -- so callers on a request path enqueue LookupArchiveUrlJob instead of calling this.
  #
  # Only 200 captures count: a 3xx capture is as often a dead article bounced to a home page as it
  # is a live one.
  #
  # Returns the snapshot URL, or nil when there is none or the archive could not be reached.
  class WaybackLookup < ApplicationService
    AVAILABILITY_API_URL = 'https://archive.org/wayback/available'
    CDX_API_URL = 'https://web.archive.org/cdx/search/cdx'
    AVAILABILITY_TIMEOUT_SECONDS = 15
    CDX_TIMEOUT_SECONDS = 90
    # Width of the columns a snapshot is stored in and may replace a link in (lex_links.url,
    # lex_citations.link); a longer snapshot URL is useless to us.
    MAX_URL_LENGTH = 1024

    def call(url)
      return nil if url.blank?

      snapshot = availability_snapshot(url) || cdx_snapshot(url)
      snapshot if snapshot && snapshot.length <= MAX_URL_LENGTH
    end

    private

    def availability_snapshot(url)
      closest = get_json(AVAILABILITY_API_URL, { url: url }, AVAILABILITY_TIMEOUT_SECONDS)
                &.dig('archived_snapshots', 'closest')
      return nil unless closest.is_a?(Hash) && closest['available'] && closest['status'] == '200'

      # The API reports snapshots as http://, which the Wayback Machine itself redirects to https
      closest['url'].to_s.sub(%r{\Ahttp://}, 'https://').presence
    end

    # limit=-1 asks for the last matching capture; the response is a header row plus data rows.
    def cdx_snapshot(url)
      params = { url: url, output: 'json', fl: 'timestamp,original', filter: 'statuscode:200', limit: -1,
                 fastLatest: true }
      rows = get_json(CDX_API_URL, params, CDX_TIMEOUT_SECONDS)
      timestamp, original = rows.last if rows.is_a?(Array) && rows.size > 1
      return nil if timestamp.blank? || original.blank?

      "https://web.archive.org/web/#{timestamp}/#{original}"
    end

    def get_json(api_url, params, timeout)
      response = Faraday.get(api_url, params, { 'User-Agent' => CheckExternalLinks::USER_AGENT }) do |req|
        req.options.timeout = timeout
        req.options.open_timeout = timeout
      end
      return nil unless response.success?

      JSON.parse(response.body)
    # Best effort: a failed lookup must never block the link check or the edit that triggered it
    rescue StandardError => e
      Rails.logger.warn("Lexicon::WaybackLookup: #{api_url} failed for #{params[:url]}: #{e.message}")
      nil
    end
  end
end
