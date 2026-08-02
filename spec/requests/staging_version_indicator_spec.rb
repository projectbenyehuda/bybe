# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Staging version indicator', type: :request do
  let!(:static_page) { create(:static_page) }

  around do |example|
    original_upper = ENV.fetch('CACHE_NONCE', nil)
    original_lower = ENV.fetch('cache_nonce', nil)

    begin
      example.run
    ensure
      ENV['CACHE_NONCE'] = original_upper
      ENV['cache_nonce'] = original_lower
    end
  end

  it 'shows the version indicator when running on staging' do
    ENV['CACHE_NONCE'] = 'staging'
    ENV['cache_nonce'] = nil
    get static_pages_by_tag_path(static_page.tag)
    expect(response).to have_http_status(:success)
    expect(response.body).to include('staging-version-indicator')
    # no REVISION file/release dir in the test checkout, so the version is reported as unknown
    expect(response.body).to include(I18n.t(:staging_version, version: I18n.t(:version_unknown)))
  end

  it 'does not show the version indicator outside staging' do
    ENV['CACHE_NONCE'] = nil
    ENV['cache_nonce'] = nil
    get static_pages_by_tag_path(static_page.tag)
    expect(response).to have_http_status(:success)
    expect(response.body).not_to include('staging-version-indicator')
  end
end
