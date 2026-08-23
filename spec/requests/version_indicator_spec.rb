# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Version indicator', type: :request do
  let!(:static_page) { create(:static_page) }

  around do |example|
    original_upper = ENV.fetch('CACHE_NONCE', nil)
    original_lower = ENV.fetch('cache_nonce', nil)
    original_sha = ENV.fetch('GIT_SHA', nil)
    original_committed_at = ENV.fetch('GIT_COMMITTED_AT', nil)

    begin
      example.run
    ensure
      ENV['CACHE_NONCE'] = original_upper
      ENV['cache_nonce'] = original_lower
      ENV['GIT_SHA'] = original_sha
      ENV['GIT_COMMITTED_AT'] = original_committed_at
    end
  end

  describe 'staging banner' do
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

  describe 'deployed build stamp' do
    before do
      ENV['CACHE_NONCE'] = nil
      ENV['cache_nonce'] = nil
      ENV['GIT_SHA'] = 'deadbeefcafe1234567890abcdef1234567890ab'
      ENV['GIT_COMMITTED_AT'] = '2026-08-20T14:05:00+03:00'
    end

    it 'shows the deployed commit and timestamp to an editor' do
      login_as(create(:user, editor: true))
      get static_pages_by_tag_path(static_page.tag)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('deployment-version-indicator')
      expect(response.body).to include('deadbeef') # short SHA in the collapsed summary
      expect(response.body).to include("#{ApplicationHelper::GITHUB_REPO_URL}/commit/#{ENV.fetch('GIT_SHA')}")
      expect(response.body).to include('2026-08-20')
    end

    it 'shows the deployed commit to an admin who is not an editor' do
      login_as(create(:user, :admin))
      get static_pages_by_tag_path(static_page.tag)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('deployment-version-indicator')
    end

    it 'hides it from a logged-in user who is neither editor nor admin' do
      login_as(create(:user))
      get static_pages_by_tag_path(static_page.tag)

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('deployment-version-indicator')
    end

    it 'hides it from anonymous visitors' do
      get static_pages_by_tag_path(static_page.tag)

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('deployment-version-indicator')
    end

    it 'yields to the staging banner rather than rendering both in the same corner' do
      ENV['CACHE_NONCE'] = 'staging'
      login_as(create(:user, editor: true))
      get static_pages_by_tag_path(static_page.tag)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('staging-version-indicator')
      expect(response.body).not_to include('deployment-version-indicator')
    end
  end
end
