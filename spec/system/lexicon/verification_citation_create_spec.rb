# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Adding a citation from the verification page', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
  end

  let(:entry) { create(:lex_entry, :person, status: :draft) }
  let(:person) { entry.lex_item }
  let!(:existing_citation) { create(:lex_citation, person: person, title: 'מראה מקום קיים') }

  it 'reloads the verification view so the new citation shows' do
    visit lexicon_verification_path(entry)
    expect(page).to have_css("#citation-#{existing_citation.id}")

    click_on I18n.t('lexicon.verification.migrated.add_citation')

    within('#generalDlg') do
      fill_in 'lex_citation_title', with: 'מראה מקום חדש'
      fill_in 'lex_citation_from_publication', with: 'כתב עת כלשהו'
      click_on I18n.t(:save)
    end

    # The page reloads, so the new card appears in the migrated pane without any manual refresh
    expect(page).to have_css('.citation-card', text: 'מראה מקום חדש', wait: 10)

    new_citation = person.citations.reload.find_by!(title: 'מראה מקום חדש')
    expect(page).to have_css("#citation-#{new_citation.id}")
    expect(page).to have_css("#citation-#{existing_citation.id}")
  end
end
