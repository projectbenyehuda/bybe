# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'resolv'
require 'ipaddr'

module Lexicon
  # Checks all external links associated with a LexEntry during migration.
  #
  # For each link (LexLink or LexCitation.link):
  # - Validates that the target host is not a private/loopback address (SSRF guard)
  # - Makes an HTTP HEAD request (falls back to GET when the server rejects HEAD)
  # - Follows up to MAX_REDIRECTS redirects
  # - Stores the final HTTP status code on the record (nil = check failed)
  # - 4xx/5xx codes indicate a broken link
  #
  # Invoked asynchronously via Lexicon::CheckExternalLinksJob after ingestion.
  class CheckExternalLinks < ApplicationService
    MAX_REDIRECTS = 5
    TIMEOUT_SECONDS = 15
    REDIRECT_STATUSES = [301, 302, 303, 307, 308].freeze

    # Statuses that commonly mean "this server dislikes HEAD" rather than "this URL is broken".
    # Plenty of servers reject HEAD with 400/403/501 instead of the correct 405, so we retry
    # once with GET before believing the link is dead.
    HEAD_REJECTED_STATUSES = [400, 403, 405, 501].freeze

    # Deliberately does NOT contain the word "link": mod_security's stock bad-bot rules match
    # /link/ (as in "linkchecker") in the User-Agent and answer 403 to everything. www.text.org.il
    # does exactly this -- `Project-Ben-Yehuda/1.0 (link-checker; +...)` gets a blanket 403 there
    # while `Project-Ben-Yehuda/1.0 (+...)` gets 200. Keep us identifiable, just not by that token.
    USER_AGENT = 'Project-Ben-Yehuda/1.0 (+https://benyehuda.org)'

    # RFC1918, loopback, link-local, and IPv6 private ranges to block (SSRF guard)
    PRIVATE_IP_RANGES = [
      IPAddr.new('127.0.0.0/8'),
      IPAddr.new('10.0.0.0/8'),
      IPAddr.new('172.16.0.0/12'),
      IPAddr.new('192.168.0.0/16'),
      IPAddr.new('169.254.0.0/16'),
      IPAddr.new('::1/128'),
      IPAddr.new('fc00::/7'),
      IPAddr.new('fe80::/10')
    ].freeze

    def call(lex_entry)
      item = lex_entry.lex_item
      return unless item

      check_item_links(item)
      check_citation_links(item) if item.is_a?(LexPerson)
    end

    # Check a single URL and return its HTTP status code (or nil on error).
    def check_url(url)
      fetch_status(url)
    end

    private

    def check_item_links(item)
      item.links.find_each do |lex_link|
        next unless external_url?(lex_link.url)

        status = fetch_status(lex_link.url)
        lex_link.update_columns(http_status: status, checked_at: Time.current)
      end
    end

    def check_citation_links(person)
      person.citations.where.not(link: [nil, '']).find_each do |citation|
        next unless external_url?(citation.link)

        status = fetch_status(citation.link)
        citation.update_columns(link_http_status: status, link_checked_at: Time.current)
      end
    end

    def external_url?(url)
      url.to_s.start_with?('http://', 'https://')
    end

    # Returns the final HTTP status code after following redirects, or nil on error.
    def fetch_status(url)
      return nil if url.blank?

      uri = parse_uri(url)
      return nil unless uri
      return nil unless ssrf_safe?(uri)

      follow_redirects(uri, MAX_REDIRECTS)
    rescue StandardError => e
      Rails.logger.warn("Lexicon::CheckExternalLinks: failed to check #{url}: #{e.message}")
      nil
    end

    # Errors propagate to fetch_status where they are logged.
    def follow_redirects(uri, remaining_hops)
      return nil if remaining_hops <= 0

      response = make_request(uri)
      return nil unless response

      status = response.code.to_i

      if REDIRECT_STATUSES.include?(status) && response['location'].present?
        new_uri = resolve_redirect(uri, response['location'])
        return follow_redirects(new_uri, remaining_hops - 1) if new_uri
      end

      status
    end

    def make_request(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                          open_timeout: TIMEOUT_SECONDS,
                                          read_timeout: TIMEOUT_SECONDS) do |http|
        request = Net::HTTP::Head.new(uri.request_uri, default_headers)
        response = http.request(request)

        # Fall back to GET if the server appears to be rejecting the HEAD method itself
        if HEAD_REJECTED_STATUSES.include?(response.code.to_i)
          request = Net::HTTP::Get.new(uri.request_uri, default_headers)
          response = http.request(request)
        end

        response
      end
    end

    def default_headers
      { 'User-Agent' => USER_AGENT }
    end

    def parse_uri(url)
      uri = URI.parse(url.strip)
      return nil unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      return nil if uri.host.blank?

      uri
    rescue URI::InvalidURIError
      nil
    end

    # SSRF guard: resolve hostname and reject requests to private/loopback addresses.
    def ssrf_safe?(uri)
      addresses = Resolv.getaddresses(uri.host)
      return false if addresses.empty?

      addresses.none? { |addr| private_address?(addr) }
    rescue Resolv::ResolvError, Resolv::ResolvTimeout
      false
    end

    def private_address?(addr)
      PRIVATE_IP_RANGES.any? { |range| range.include?(addr) }
    rescue IPAddr::InvalidAddressError
      true # Treat unrecognised addresses as unsafe
    end

    def resolve_redirect(base_uri, location)
      # Location may be absolute or relative
      redirect_uri = URI.parse(location)
      redirect_uri = base_uri.merge(redirect_uri) unless redirect_uri.absolute?
      return nil unless redirect_uri.is_a?(URI::HTTP) || redirect_uri.is_a?(URI::HTTPS)

      redirect_uri
    rescue URI::InvalidURIError
      nil
    end
  end
end
