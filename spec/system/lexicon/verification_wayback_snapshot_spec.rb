# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Internet Archive snapshots of broken links on the verification page', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
    allow(Lexicon::CheckExternalLinks).to receive(:new)
      .and_return(instance_double(Lexicon::CheckExternalLinks, check_url: link_check_result(200)))
    allow(Lexicon::MondayReport).to receive(:call).and_return({ success: true })
  end

  let(:entry) { create(:lex_entry, :person, status: :draft) }
  let(:person) { entry.lex_item }
  let(:dead_url) { 'https://broken.example.com/old' }
  let(:snapshot) { "https://web.archive.org/web/20200101000000/#{dead_url}" }
  let(:archived_version) { I18n.t('lexicon.verification.broken_link.archived_version') }
  let(:use_archived_version) { I18n.t('lexicon.verification.broken_link.use_archived_version') }

  context 'with a broken citation link that has a snapshot' do
    let!(:citation) do
      create(:lex_citation, person: person, title: 'Test Article', link: dead_url, link_http_status: 404,
                            link_checked_at: Time.current, link_archive_url: snapshot)
    end

    it 'links to the snapshot and replaces the link with it on request' do
      visit lexicon_verification_path(entry)

      within("#citation-#{citation.id}") do
        expect(page).to have_link(archived_version, href: snapshot)
        accept_confirm { click_link use_archived_version }
      end

      expect(page).to have_css('.toast-notification.toast-success',
                               text: I18n.t('lexicon.verification.broken_link.now_accessible'), wait: 8)
      within("#citation-#{citation.id}") do
        expect(page).to have_no_css('.broken-link-badge')
        expect(page).to have_link(snapshot, href: snapshot)
      end
      expect(citation.reload.link).to eq(snapshot)
    end
  end

  context 'with a broken link that has a snapshot' do
    let!(:link) do
      create(:lex_link, item: person, url: dead_url, http_status: 404, checked_at: Time.current,
                        archive_url: snapshot)
    end

    it 'replaces the link with the snapshot on request' do
      visit lexicon_verification_path(entry)

      within("#link-#{link.id}") do
        accept_confirm { click_link use_archived_version }
      end

      within('#section-links') do
        expect(page).to have_link(snapshot, href: snapshot, wait: 8)
        expect(page).to have_no_css('.broken-link-badge')
      end
      expect(link.reload.url).to eq(snapshot)
    end
  end

  context 'with a broken link that has no snapshot' do
    let!(:link) { create(:lex_link, item: person, url: dead_url, http_status: 404, checked_at: Time.current) }

    it 'falls back to searching the Internet Archive' do
      visit lexicon_verification_path(entry)

      within("#link-#{link.id}") do
        expect(page).to have_link(I18n.t('lexicon.verification.broken_link.internet_archive'),
                                  href: "https://web.archive.org/web/*/#{dead_url}")
        expect(page).to have_no_link(use_archived_version)
      end
    end
  end
end
