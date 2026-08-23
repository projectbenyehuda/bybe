# frozen_string_literal: true

require 'rails_helper'

# Links behind a bot challenge (e.g. www.nli.org.il behind Cloudflare) cannot be checked from our
# datacenter IP. The verification workbench must say so neutrally instead of crying "broken link".
# See by-9jz.
RSpec.describe 'Unverifiable link badge on verification page', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
  end

  let(:entry) { create(:lex_entry, :person, status: :draft) }
  let(:person) { entry.lex_item }

  let(:badge_text) { I18n.t('lexicon.verification.broken_link.unverifiable_badge') }
  let(:broken_badge_text) { I18n.t('lexicon.verification.broken_link.badge', status: 403) }

  context 'with a link that was challenged by the host' do
    let!(:link) do
      create(:lex_link,
             item: person,
             url: 'https://www.nli.org.il/he/archives/NNL_ALEPH000000001',
             http_status: 403,
             unverifiable: true,
             checked_at: Time.current)
    end

    it 'shows the neutral verify-manually badge instead of the broken-link badge' do
      visit lexicon_verification_path(entry)

      within("#link-#{link.id}") do
        expect(page).to have_css('.unverifiable-link-badge', text: badge_text)
        expect(page).to have_no_css('.broken-link-badge')
      end
    end

    it 'does not style the card as a broken link' do
      visit lexicon_verification_path(entry)

      expect(page).to have_css("#link-#{link.id}.unverifiable-link")
      expect(page).to have_no_css("#link-#{link.id}.broken-link")
    end

    it 'explains in the tooltip that the URL must be opened in a browser' do
      visit lexicon_verification_path(entry)

      expect(page).to have_css("#link-#{link.id} .unverifiable-link-badge")
      badge = find("#link-#{link.id} .unverifiable-link-badge")
      expect(badge[:title]).to eq(I18n.t('lexicon.verification.broken_link.unverifiable_tooltip'))
    end
  end

  context 'with a link that is genuinely broken' do
    let!(:link) do
      create(:lex_link,
             item: person,
             url: 'https://broken.example.com/gone',
             http_status: 403,
             unverifiable: false,
             checked_at: Time.current)
    end

    it 'still shows the red broken-link badge' do
      visit lexicon_verification_path(entry)

      within("#link-#{link.id}") do
        expect(page).to have_css('.broken-link-badge', text: broken_badge_text)
        expect(page).to have_no_css('.unverifiable-link-badge')
      end
    end
  end

  context 'with a citation whose link was challenged by the host' do
    let!(:citation) do
      create(:lex_citation,
             person: person,
             title: 'Test Article',
             link: 'https://www.nli.org.il/he/newspapers/example',
             link_http_status: 403,
             link_unverifiable: true,
             link_checked_at: Time.current)
    end

    it 'shows the neutral verify-manually badge on the citation' do
      visit lexicon_verification_path(entry)

      within("#citation-#{citation.id}") do
        expect(page).to have_css('.unverifiable-link-badge', text: badge_text)
        expect(page).to have_no_css('.broken-link-badge')
      end
    end
  end
end
