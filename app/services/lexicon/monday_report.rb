# frozen_string_literal: true

require 'net/http'

module Lexicon
  # Posts a report item to Monday.com via its REST/GraphQL API.
  # Used from the verification workbench for general notes and missing-work flags.
  class MondayReport
    MONDAY_API_URL = 'https://api.monday.com/v2'

    def self.call(**)
      new(**).call
    end

    # @param entry [LexEntry]
    # @param report_type [Symbol] :general or :missing_work
    # @param current_url [String] full URL of the verification page
    # @param description [String, nil] free-text (only for :general reports)
    # @param work_title [String, nil] title of the specific work (only for :missing_work)
    def initialize(entry:, report_type:, current_url:, description: nil, work_title: nil)
      @entry = entry
      @report_type = report_type
      @current_url = current_url
      @description = description
      @work_title = work_title
    end

    def call
      board_id = ENV.fetch('MONDAY_BOARD_ID', nil)
      token = ENV.fetch('MONDAY_API_TOKEN', nil)

      if board_id.blank? || token.blank?
        return { success: false,
                 error: 'Monday integration not configured (MONDAY_BOARD_ID or MONDAY_API_TOKEN missing)' }
      end

      column_values = build_column_values
      body = build_request_body(board_id, column_values)
      response = post_to_monday(token, body)
      parse_response(response)
    rescue StandardError => e
      Rails.logger.error("Lexicon::MondayReport: #{e.message}")
      { success: false, error: e.message }
    end

    private

    def build_column_values
      values = {
        'name' => item_name_column,
        'text_mm2tn5yc' => @entry.title,
        'link_mm2t7e9n' => { 'url' => @current_url, 'text' => I18n.t('lexicon.verification.monday.link_text') }
      }
      values['long_text_mm2tzz8q'] = @description if @report_type == :general && @description.present?
      values
    end

    def item_name_column
      if @report_type == :missing_work
        I18n.t('lexicon.verification.monday.missing_work_name', title: @work_title || @entry.title)
      else
        I18n.t('lexicon.verification.monday.general_name')
      end
    end

    def build_request_body(board_id, column_values)
      # column_values in Monday's API is a JSON *string* argument inside GraphQL.
      # Double-encode: .to_json converts the hash to a JSON string, then .to_json
      # JSON-encodes that string (adding surrounding quotes + escaping inner quotes).
      mutation = "mutation { create_item(board_id: #{board_id} item_name: #{@entry.title.to_json} " \
                 "column_values: #{column_values.to_json.to_json}) { id name url } }"
      { query: mutation }.to_json
    end

    def post_to_monday(token, body)
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

    def parse_response(response)
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
  end
end
