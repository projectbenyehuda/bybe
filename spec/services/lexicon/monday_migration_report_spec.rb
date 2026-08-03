# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lexicon::MondayMigrationReport do
  include WebMock::API

  let(:entry) { create(:lex_entry, :person, title: 'מוישה זוכמיר') }
  let(:verifier) { create(:user, name: 'שרה בודקת') }
  let(:entry_url) { 'https://benyehuda.org/lex/verification/1234' }

  before do
    WebMock.disable_net_connect!(allow_localhost: true)
    stub_const('ENV', ENV.to_h.merge('LEXICON_MIGRATED_MONDAY_BOARD_ID' => '5101520421',
                                     'MONDAY_API_TOKEN' => 'test-token'))
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

  def report(user = verifier)
    described_class.call(entry: entry, verifier: user, entry_url: entry_url)
  end

  describe '.call' do
    it 'returns success when the Monday API succeeds' do
      stub_monday_success

      expect(report[:success]).to be true
    end

    it 'posts to the migrated-entries board, not the issues board' do
      captured_body = nil
      stub_monday_success { |req| captured_body = req.body }

      report

      expect(JSON.parse(captured_body)['query']).to include('board_id: 5101520421')
    end

    it 'names the item after the entry title' do
      captured_body = nil
      stub_monday_success { |req| captured_body = req.body }

      report

      expect(JSON.parse(captured_body)['query']).to include('item_name: "מוישה זוכמיר"')
    end

    it 'sends the entry title in the title column' do
      captured_body = nil
      stub_monday_success { |req| captured_body = req.body }

      report

      expect(column_values(captured_body)).to include('text_mm2tn5yc' => 'מוישה זוכמיר')
    end

    it 'sends the verifying user name in the verifier column' do
      captured_body = nil
      stub_monday_success { |req| captured_body = req.body }

      report

      expect(column_values(captured_body)).to include('text_mm5wq5fh' => 'שרה בודקת')
    end

    it 'sends the verification page URL in the link column' do
      captured_body = nil
      stub_monday_success { |req| captured_body = req.body }

      report

      expect(column_values(captured_body)['link_mm2t7e9n']).to eq(
        'url' => entry_url, 'text' => I18n.t('lexicon.verification.monday.link_text')
      )
    end

    it 'leaves the checker column empty, to be assigned interactively on Monday' do
      captured_body = nil
      stub_monday_success { |req| captured_body = req.body }

      report

      expect(column_values(captured_body)).not_to have_key('multiple_person_mm5wkq09')
    end

    it 'omits the verifier column when there is no signed-in user' do
      captured_body = nil
      stub_monday_success { |req| captured_body = req.body }

      report(nil)

      expect(column_values(captured_body)).not_to have_key('text_mm5wq5fh')
    end

    it 'sends the Authorization header with the token' do
      captured_headers = nil
      stub_monday_success { |req| captured_headers = req.headers }

      report

      expect(captured_headers['Authorization']).to eq('test-token')
    end

    context 'when the board id is not configured' do
      before { stub_const('ENV', ENV.to_h.merge('LEXICON_MIGRATED_MONDAY_BOARD_ID' => nil)) }

      it 'returns an error without making an HTTP request' do
        # WebMock raises on any unstubbed request, so reaching the expectation
        # at all confirms no HTTP call was attempted.
        result = report

        expect(result[:success]).to be false
        expect(result[:error]).to include('not configured')
      end
    end

    context 'when the Monday API returns an error response' do
      before do
        stub_request(:post, 'https://api.monday.com/v2').to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json' },
          body: { errors: [{ message: 'Invalid auth token' }] }.to_json
        )
      end

      it 'returns failure with the error message' do
        result = report

        expect(result[:success]).to be false
        expect(result[:error]).to include('Invalid auth token')
      end
    end

    context 'when the network call times out' do
      before { stub_request(:post, 'https://api.monday.com/v2').to_timeout }

      it 'returns failure without raising' do
        result = report

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end
    end
  end

  # column_values travels as a JSON string nested inside the GraphQL mutation string.
  def column_values(request_body)
    query = JSON.parse(request_body)['query']
    JSON.parse(query[/column_values: ("(?:\\.|[^"\\])*")/, 1].then { |json| JSON.parse(json) })
  end
end
