# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API keys management', :js, type: :system do
  let(:admin) { create(:user, editor: true, admin: true) }
  let!(:api_key) { create(:api_key, email: 'researcher@example.com', description: 'Corpus study', status: :enabled) }

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as(admin)
  end

  it 'is reachable from the admin dashboard' do
    visit admin_index_path
    click_link I18n.t('api_keys.index.title')
    expect(page).to have_css('#api_keys_table', text: 'researcher@example.com')
    expect(page).to have_css("#api_key_#{api_key.id}", text: 'Corpus study')
    expect(page).to have_link(I18n.t('api_keys.index.download_csv'))
  end

  it 'disables and re-enables a key' do
    visit api_keys_path
    row = "#api_key_#{api_key.id}"

    accept_confirm { within(row) { click_button I18n.t('api_keys.index.disable') } }
    expect(page).to have_css(row, text: I18n.t('api_keys.index.statuses.disabled'))
    expect(api_key.reload).to be_status_disabled

    within(row) { click_button I18n.t('api_keys.index.enable') }
    expect(page).to have_css(row, text: I18n.t('api_keys.index.statuses.enabled'))
    expect(api_key.reload).to be_status_enabled
  end
end
