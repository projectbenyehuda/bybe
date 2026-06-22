# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lexicon::MondayReport do
  include WebMock::API

  let(:entry) { create(:lex_entry, :person, title: 'מוישה זוכמיר') }
  let(:current_url) { 'https://benyehuda.org/lex/verification/1234' }
  let(:captured_request) { {} }

  before do
    WebMock.disable_net_connect!(allow_localhost: true)
    stub_const('ENV', ENV.to_h.merge('MONDAY_BOARD_ID' => '5095697584', 'MONDAY_API_TOKEN' => 'test-token'))
  end

  def stub_monday_success(&block)
    stub_request(:post, 'https://api.monday.com/v2').to_return do |request|
      block&.call(request)
      {
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { data: { create_item: { id: '123', name: 'מוישה זוכמיר', url: 'https://monday.com/item/123' } } }.to_json
      }
    end
  end

  def stub_monday_error(message = 'Invalid token')
    stub_request(:post, 'https://api.monday.com/v2')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { errors: [{ message: message }] }.to_json
      )
  end

  describe '.call' do
    context 'when Monday env vars are not configured' do
      before { stub_const('ENV', ENV.to_h.merge('MONDAY_BOARD_ID' => nil, 'MONDAY_API_TOKEN' => nil)) }

      it 'returns an error without making an HTTP request' do
        # VCR/WebMock will raise if an unexpected HTTP call is made,
        # so the absence of an error confirms no request was attempted.
        result = described_class.call(entry: entry, report_type: :general, current_url: current_url)

        expect(result[:success]).to be false
        expect(result[:error]).to include('not configured')
      end
    end

    context 'with a general report' do
      it 'returns success when Monday API succeeds' do
        stub_monday_success
        result = described_class.call(
          entry: entry,
          report_type: :general,
          current_url: current_url,
          description: 'נראה שחסר פה ככה וככה'
        )

        expect(result[:success]).to be true
      end

      it 'sends the entry title in the request body' do
        captured_body = nil
        stub_monday_success { |req| captured_body = req.body }

        described_class.call(entry: entry, report_type: :general, current_url: current_url)

        expect(captured_body).to include('מוישה זוכמיר')
      end

      it 'sends the general_name I18n text in the body' do
        captured_body = nil
        stub_monday_success { |req| captured_body = req.body }
        expected = I18n.t('lexicon.verification.monday.general_name')

        described_class.call(entry: entry, report_type: :general, current_url: current_url)

        expect(captured_body).to include(expected)
      end

      it 'includes the description in the body' do
        captured_body = nil
        stub_monday_success { |req| captured_body = req.body }
        description = 'נראה שחסר פה ככה וככה'

        described_class.call(entry: entry, report_type: :general, current_url: current_url, description: description)

        expect(captured_body).to include(description)
      end

      it 'includes the current_url in the body' do
        captured_body = nil
        stub_monday_success { |req| captured_body = req.body }

        described_class.call(entry: entry, report_type: :general, current_url: current_url)

        expect(captured_body).to include('benyehuda.org')
      end

      it 'sends the Authorization header with the token' do
        captured_headers = nil
        stub_monday_success { |req| captured_headers = req.headers }

        described_class.call(entry: entry, report_type: :general, current_url: current_url)

        expect(captured_headers['Authorization']).to eq('test-token')
      end

      it 'omits long_text column when description is blank' do
        captured_body = nil
        stub_monday_success { |req| captured_body = req.body }

        described_class.call(entry: entry, report_type: :general, current_url: current_url, description: nil)

        expect(captured_body).not_to include('long_text_mm2tzz8q')
      end
    end

    context 'with a missing_work report' do
      let(:work_title) { 'שיר ערש' }

      it 'returns success when Monday API succeeds' do
        stub_monday_success
        result = described_class.call(
          entry: entry,
          report_type: :missing_work,
          current_url: current_url,
          work_title: work_title
        )

        expect(result[:success]).to be true
      end

      it 'includes the work title in the missing_work_name text' do
        captured_body = nil
        stub_monday_success { |req| captured_body = req.body }
        expected = I18n.t('lexicon.verification.monday.missing_work_name', title: work_title)

        described_class.call(
          entry: entry, report_type: :missing_work, current_url: current_url, work_title: work_title
        )

        expect(captured_body).to include(expected)
      end

      it 'omits long_text column' do
        captured_body = nil
        stub_monday_success { |req| captured_body = req.body }

        described_class.call(
          entry: entry, report_type: :missing_work, current_url: current_url, work_title: work_title
        )

        expect(captured_body).not_to include('long_text_mm2tzz8q')
      end
    end

    context 'when Monday API returns an error response' do
      before { stub_monday_error('Invalid auth token') }

      it 'returns failure with the error message' do
        result = described_class.call(entry: entry, report_type: :general, current_url: current_url)

        expect(result[:success]).to be false
        expect(result[:error]).to include('Invalid auth token')
      end
    end

    context 'when the network call times out' do
      before { stub_request(:post, 'https://api.monday.com/v2').to_timeout }

      it 'returns failure without raising' do
        result = described_class.call(entry: entry, report_type: :general, current_url: current_url)

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end
    end
  end
end
