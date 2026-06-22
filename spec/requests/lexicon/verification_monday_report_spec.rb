# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /lex/verification/:id/report_to_monday', type: :request do
  let(:person) { create(:lex_person) }
  let(:entry) do
    e = create(:lex_entry, :person, lex_item: person, status: :verifying)
    e.start_verification!('editor@example.com')
    e
  end
  let(:url) { "/lex/verification/#{entry.id}/report_to_monday" }

  before { login_as_lexicon_editor }

  context 'when Monday integration is configured' do
    before do
      stub_const('ENV', ENV.to_h.merge('MONDAY_BOARD_ID' => '12345', 'MONDAY_API_TOKEN' => 'test-token'))
      allow(Lexicon::MondayReport).to receive(:call).and_return({ success: true })
    end

    it 'delegates to the MondayReport service for a general report' do
      post url, params: { type: 'general', description: 'some notes' }, as: :json

      expect(Lexicon::MondayReport).to have_received(:call).with(
        hash_including(report_type: :general, description: 'some notes')
      )
    end

    it 'delegates to the MondayReport service for a missing_work report' do
      post url, params: { type: 'missing_work', work_title: 'שיר ערש' }, as: :json

      expect(Lexicon::MondayReport).to have_received(:call).with(
        hash_including(report_type: :missing_work, work_title: 'שיר ערש')
      )
    end

    it 'returns 200 with success message on success' do
      post url, params: { type: 'general', description: 'notes' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['success']).to be true
    end

    it 'passes the verification page URL to the service' do
      post url, params: { type: 'general' }, as: :json

      expect(Lexicon::MondayReport).to have_received(:call).with(
        hash_including(current_url: %r{/lex/verification/#{entry.id}})
      )
    end
  end

  context 'when the service returns an error' do
    before do
      stub_const('ENV', ENV.to_h.merge('MONDAY_BOARD_ID' => '12345', 'MONDAY_API_TOKEN' => 'test-token'))
      allow(Lexicon::MondayReport).to receive(:call).and_return({ success: false, error: 'API error' })
    end

    it 'returns 422 with the error' do
      post url, params: { type: 'general' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to eq('API error')
    end
  end
end
