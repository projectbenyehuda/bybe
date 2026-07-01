# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rack::Attack throttling', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  around do |example|
    original_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.reset!
    # Rack::Attack buckets counts by wall-clock time / period, so freeze time to
    # avoid flakiness from the bucket rolling over mid-test.
    freeze_time do
      example.run
    end
    Rack::Attack.cache.store = original_store
  end

  let(:ip) { '203.0.113.7' }

  before do
    self.remote_addr = ip
  end

  it 'throttles regular (non-asset) paths after 100 requests per IP within the window' do
    101.times { get '/this-path-does-not-exist' }

    expect(response.status).to eq(429)
  end

  it 'gives /assets and /rails/active_storage paths a much higher throttle bucket' do
    101.times { get '/assets/does-not-exist.js' }
    expect(response.status).not_to eq(429)

    101.times { get '/rails/active_storage/blobs/redirect/x/y.jpg' }
    expect(response.status).not_to eq(429)
  end
end
