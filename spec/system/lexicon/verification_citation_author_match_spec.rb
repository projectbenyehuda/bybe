# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Matching an imported citation author to an existing entry', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
  end

  # Chewy indices are not rolled back with the database, so entries imported for the autocomplete
  # would otherwise pile up across examples and turn one expected suggestion into several.
  after { Chewy.massacre }

  let(:entry) { create(:lex_entry, :person, status: :draft) }
  let(:person) { entry.lex_item }
  let!(:citation) { create(:lex_citation, person: person, title: 'מאמר על המשוררת', authors_count: 0) }
  # Imported from the legacy PHP file as "lastname, firstname", which is never how an entry is titled
  let!(:author) { create(:lex_citation_author, citation: citation, name: 'איזיקוביץ, גילי', link: nil) }

  let(:match_button_label) { I18n.t('lexicon.citation_authors.match.title') }

  context 'when a person entry is titled like the normalized name' do
    let!(:matching_entry) { create(:lex_entry, :person, title: 'גילי איזיקוביץ') }

    before { import_and_await(LexEntriesAutocompleteIndex, [matching_entry]) }

    it 'offers the match button next to the plaintext author' do
      visit lexicon_verification_path(entry)

      within("#citation-#{citation.id}") do
        expect(page).to have_content('איזיקוביץ, גילי')
        expect(page).to have_button(match_button_label)
      end
    end

    it 'links the author to the chosen entry while keeping the imported name' do
      visit lexicon_verification_path(entry)

      within("#citation-#{citation.id}") { click_button match_button_label }
      expect(page).to have_css('#generalDlg', visible: :visible)

      # The modal opens pre-filled with the processed name the match was found by
      expect(page).to have_field('lex_citation_author_name', with: 'גילי איזיקוביץ')

      fill_in 'lex_citation_author_name', with: 'גילי'
      expect(page).to have_css('ul.ui-autocomplete li', text: matching_entry.title, wait: 5)
      find('ul.ui-autocomplete li', text: matching_entry.title).click

      click_button I18n.t('lexicon.citation_authors.match.confirm')

      # The page reloads on success, and the author now renders as a link to the entry --
      # still labelled with the name exactly as the legacy file had it.
      within("#citation-#{citation.id}") do
        expect(page).to have_link('איזיקוביץ, גילי', href: lexicon_entry_path(matching_entry), wait: 8)
        expect(page).to have_no_button(match_button_label)
      end

      expect(author.reload.entry).to eq(matching_entry)
      expect(author.name).to eq('איזיקוביץ, גילי')
    end

    it 'leaves the author alone when the modal is closed without confirming' do
      visit lexicon_verification_path(entry)

      within("#citation-#{citation.id}") { click_button match_button_label }
      expect(page).to have_css('#generalDlg', visible: :visible)

      click_button I18n.t(:cancel)

      expect(page).to have_css('#generalDlg', visible: :hidden)
      expect(author.reload.entry).to be_nil
      expect(author.name).to eq('איזיקוביץ, גילי')
    end
  end

  context 'when no person entry carries that name' do
    it 'does not offer the match button' do
      visit lexicon_verification_path(entry)

      within("#citation-#{citation.id}") do
        expect(page).to have_content('איזיקוביץ, גילי')
        expect(page).to have_no_button(match_button_label)
      end
    end
  end
end
