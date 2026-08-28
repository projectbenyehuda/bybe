# frozen_string_literal: true

require 'rails_helper'

# Authority control identifiers used to be editable only from the migration verification
# workbench. The entry edit page now carries a tab for them too.
RSpec.describe 'Lexicon entry edit – authority control tab', :js, type: :system do
  let(:person) { create(:lex_person) }
  let(:entry) do
    create(:lex_entry, :person,
           title: 'Test Person',
           lex_item: person,
           status: :draft,
           external_identifiers: { 'viaf' => '12345678', 'lc' => 'n87654321' })
  end

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
    visit edit_lexicon_entry_path(entry)
    click_link I18n.t('lexicon.entries.edit.external_identifiers')
    # The pane is loaded lazily on first click; wait it out before touching any field. find_field
    # rather than an expectation because RSpec forbids expect in a hook -- it still waits, and
    # still fails loudly (Capybara::ElementNotFound) if the pane never arrives.
    page.find_field('external_identifiers[viaf]', with: '12345678', wait: 10)
  end

  it 'shows a field per identifier key, pre-filled with the stored values' do
    within '#external_identifiers' do
      expect(page).to have_field('external_identifiers[viaf]', with: '12345678')
      expect(page).to have_field('external_identifiers[lc]', with: 'n87654321')
      expect(page).to have_field('external_identifiers[nli]', with: '')
      expect(page).to have_field('external_identifiers[wikidata]', with: '')
      expect(page).to have_field('external_identifiers[openlibrary]', with: '')
    end
  end

  it 'saves an added identifier' do
    within '#external_identifiers' do
      fill_in 'external_identifiers[wikidata]', with: 'Q42'
      click_button I18n.t(:save)
      # The success alert is rendered by the PATCH response, so waiting on it waits out the save.
      expect(page).to have_css('#external_identifiers_status .alert-success',
                               text: I18n.t('lexicon.external_identifiers.update.success'), wait: 10)
    end

    expect(entry.reload.external_identifiers).to include('wikidata' => 'Q42')
  end

  it 'removes an identifier whose field is cleared' do
    within '#external_identifiers' do
      fill_in 'external_identifiers[lc]', with: ''
      click_button I18n.t(:save)
      expect(page).to have_css('#external_identifiers_status .alert-success', wait: 10)
    end

    expect(entry.reload.external_identifiers).to eq('viaf' => '12345678')
  end
end
