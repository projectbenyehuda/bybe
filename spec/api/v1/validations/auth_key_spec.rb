# frozen_string_literal: true

require 'rails_helper'

describe V1::Validations::AuthKey do
  subject(:call) { get "/api/v1/authorities/#{authority.id}?key=#{key}" }

  include_context 'API Spec Helpers'
  include ActiveSupport::Testing::TimeHelpers

  let(:authority) { create(:authority) }

  context 'when key is valid' do
    it 'increments calls_count and sets last_used_at on each call' do
      freeze_time do
        expect(call).to eq 200
        expect(api_key.reload).to have_attributes(calls_count: 1, last_used_at: Time.current)
      end

      travel 1.hour do
        get "/api/v1/authorities/#{authority.id}?key=#{key}"
        expect(api_key.reload).to have_attributes(calls_count: 2, last_used_at: Time.current.change(usec: 0))
      end
    end

    it 'does not touch updated_at' do
      original_updated_at = api_key.updated_at
      travel(1.day) { call }
      expect(api_key.reload.updated_at).to eq original_updated_at
    end
  end

  context 'when key is disabled' do
    let(:key) { disabled_api_key.key }

    it 'does not record usage' do
      expect(call).to eq 401
      expect(disabled_api_key.reload).to have_attributes(calls_count: 0, last_used_at: nil)
    end
  end

  context 'when key is wrong' do
    let(:key) { 'WRONG KEY' }

    it 'does not record usage for any key' do
      api_key
      expect(call).to eq 401
      expect(ApiKey.sum(:calls_count)).to eq 0
    end
  end
end
