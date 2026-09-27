# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Citation link check feedback on verification page', type: :system, js: true do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
    allow_any_instance_of(Lexicon::CheckExternalLinks).to receive(:check_url).and_return(check_url_result)
  end

  let(:entry) { create(:lex_entry, :person, status: :draft) }
  let(:person) { entry.lex_item }
  let!(:citation) do
    create(:lex_citation,
           person: person,
           title: 'Test Article',
           link: 'https://broken.example.com/old',
           link_http_status: 404,
           link_checked_at: Time.current)
  end

  def visit_verification_page
    visit lexicon_verification_path(entry)
  end

  def open_citation_edit_modal
    within('#section-citations') do
      find('button.btn-outline-primary').click
    end
    expect(page).to have_css('#generalDlg.show', wait: 5)
  end

  # Scoped to the citation form: the modal also loads the citation's authors list asynchronously,
  # and each plaintext author there has its own "save link" button with the same label.
  def submit_citation_form(field, value)
    within("#generalDlg #edit_lex_citation_#{citation.id}") do
      fill_in field, with: value
      click_button I18n.t(:save)
    end
  end

  def submit_link_change(new_link)
    submit_citation_form('lex_citation_link', new_link)
  end

  context 'when the new link is accessible (HTTP 200)' do
    let(:check_url_result) { link_check_result(200) }

    it 'reloads the page and shows a green success toast' do
      visit_verification_page
      open_citation_edit_modal
      submit_link_change('https://working.example.com/article')

      # Page reloads; toast should appear after reload
      expected = I18n.t('lexicon.verification.broken_link.now_accessible')
      expect(page).to have_css('.toast-notification.toast-success', text: expected, wait: 8)
    end

    it 'removes the broken-link badge after reload' do
      visit_verification_page
      within('#section-citations') do
        expect(page).to have_css('.broken-link-badge')
      end

      open_citation_edit_modal
      submit_link_change('https://working.example.com/article')

      # After reload, the broken-link badge should be gone
      expect(page).not_to have_css('.broken-link-badge', wait: 8)
    end
  end

  context 'when the new link is still broken (HTTP 404)' do
    let(:check_url_result) { link_check_result(404) }

    it 'reloads the page and shows a red error toast' do
      visit_verification_page
      open_citation_edit_modal
      submit_link_change('https://still-broken.example.com/new')

      expected = I18n.t('lexicon.verification.broken_link.still_broken', status: 404)
      expect(page).to have_css('.toast-notification.toast-error', text: expected, wait: 8)
    end

    it 'keeps the broken-link badge after reload' do
      visit_verification_page
      open_citation_edit_modal
      submit_link_change('https://still-broken.example.com/new')

      expect(page).to have_css('.broken-link-badge', wait: 8)
    end
  end

  context 'when the new link could not be retrieved (nil status)' do
    let(:check_url_result) { link_check_result(nil) }

    it 'reloads the page and shows a red error toast' do
      visit_verification_page
      open_citation_edit_modal
      submit_link_change('https://unreachable.example.com/')

      expected = I18n.t('lexicon.verification.broken_link.inaccessible')
      expect(page).to have_css('.toast-notification.toast-error', text: expected, wait: 8)
    end

    it 'keeps the broken-link badge after reload' do
      visit_verification_page
      open_citation_edit_modal
      submit_link_change('https://unreachable.example.com/')

      expect(page).to have_css('.broken-link-badge', wait: 8)
    end
  end

  context 'when the link is not changed' do
    let(:check_url_result) { link_check_result(nil) }

    it 'reloads the page without a toast' do
      visit_verification_page
      open_citation_edit_modal

      submit_citation_form('lex_citation_title', 'Updated Title')

      # Page reloads; no toast since link was unchanged
      expect(page).not_to have_css('.toast-notification', wait: 5)
    end
  end
end
