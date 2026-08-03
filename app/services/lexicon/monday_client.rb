# frozen_string_literal: true

require 'net/http'

module Lexicon
  # Thin transport wrapper around Monday.com's GraphQL API. Creates a board item
  # and normalises everything — API errors, malformed bodies, network failures —
  # into a { success:, error: } hash, so callers never have to rescue.
  class MondayClient
    MONDAY_API_URL = 'https://api.monday.com/v2'

    # @param board_id [String, nil] target Monday board
    # @param item_name [String] the item's Name column
    # @param column_values [Hash] column id => value, in Monday's per-type format
    # @return [Hash] { success: true } or { success: false, error: String }
    def self.create_item(board_id:, item_name:, column_values:)
      token = ENV.fetch('MONDAY_API_TOKEN', nil)

      if board_id.blank? || token.blank?
        return { success: false, error: 'Monday integration not configured (board id or MONDAY_API_TOKEN missing)' }
      end

      parse_response(post(token, build_request_body(board_id, item_name, column_values)))
    rescue StandardError => e
      Rails.logger.error("Lexicon::MondayClient: #{e.message}")
      { success: false, error: e.message }
    end

    def self.build_request_body(board_id, item_name, column_values)
      # column_values in Monday's API is a JSON *string* argument inside GraphQL.
      # Double-encode: .to_json converts the hash to a JSON string, then .to_json
      # JSON-encodes that string (adding surrounding quotes + escaping inner quotes).
      mutation = "mutation { create_item(board_id: #{board_id}, item_name: #{item_name.to_json}, " \
                 "column_values: #{column_values.to_json.to_json}) { id name url } }"
      { query: mutation }.to_json
    end
    private_class_method :build_request_body

    def self.post(token, body)
      uri = URI(MONDAY_API_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 15

      request = Net::HTTP::Post.new(uri.path)
      request['Authorization'] = token
      request['Content-Type'] = 'application/json'
      request.body = body

      http.request(request)
    end
    private_class_method :post

    def self.parse_response(response)
      body = JSON.parse(response.body)
      if body.dig('data', 'create_item').present?
        { success: true }
      else
        errors = body['errors']&.map { |e| e['message'] }&.join(', ') # rubocop:disable Rails/Pluck
        { success: false, error: errors.presence || 'Unknown Monday API error' }
      end
    rescue JSON::ParserError => e
      { success: false, error: "Failed to parse Monday API response: #{e.message}" }
    end
    private_class_method :parse_response
  end
end
