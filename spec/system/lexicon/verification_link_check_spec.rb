# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'External link check feedback on verification page', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
    allow(Lexicon::CheckExternalLinks).to receive(:new).and_return(checker)
  end

  let(:checker) { instance_double(Lexicon::CheckExternalLinks, check_url: check_url_result) }
  let(:entry) { create(:lex_entry, :person, status: :draft) }
  let(:person) { entry.lex_item }
  let!(:link) do
    create(:lex_link,
           item: person,
           url: 'https://broken.example.com/old',
           http_status: 403,
           checked_at: Time.current)
  end

  def visit_verification_page
    visit lexicon_verification_path(entry)
  end

  def open_link_edit_modal
    within('#section-links') do
      find('button.btn-outline-primary').click
    end
    expect(page).to have_css('#generalDlg.show', wait: 5)
  end

  def submit_link_change(new_url)
    within('#generalDlg') do
      fill_in 'lex_link[url]', with: new_url
      click_button I18n.t(:save)
    end
  end

  context 'when the new link is accessible (HTTP 200)' do
    let(:check_url_result) { 200 }

    it 'reloads the page and shows a green success toast' do
      visit_verification_page
      open_link_edit_modal
      submit_link_change('https://working.example.com/page')

      expected = I18n.t('lexicon.verification.broken_link.now_accessible')
      expect(page).to have_css('.toast-notification.toast-success', text: expected, wait: 8)
    end

    it 'removes the broken-link badge after reload' do
      visit_verification_page
      within('#section-links') do
        expect(page).to have_css('.broken-link-badge')
      end

      open_link_edit_modal
      submit_link_change('https://working.example.com/page')

      expect(page).not_to have_css('.broken-link-badge', wait: 8)
    end
  end

  context 'when the new link is still broken (HTTP 404)' do
    let(:check_url_result) { 404 }

    it 'reloads the page and shows a red error toast' do
      visit_verification_page
      open_link_edit_modal
      submit_link_change('https://still-broken.example.com/new')

      expected = I18n.t('lexicon.verification.broken_link.still_broken', status: 404)
      expect(page).to have_css('.toast-notification.toast-error', text: expected, wait: 8)
    end

    it 'keeps the broken-link badge after reload' do
      visit_verification_page
      open_link_edit_modal
      submit_link_change('https://still-broken.example.com/new')

      expect(page).to have_css('.broken-link-badge', wait: 8)
    end
  end

  context 'when the link is not changed' do
    let(:check_url_result) { nil }

    it 'reloads the page without a toast' do
      visit_verification_page
      open_link_edit_modal

      within('#generalDlg') do
        fill_in 'lex_link[description]', with: 'Updated description'
        click_button I18n.t(:save)
      end

      expect(page).not_to have_css('.toast-notification', wait: 5)
    end
  end
end
