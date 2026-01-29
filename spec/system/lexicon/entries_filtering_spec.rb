# frozen_string_literal: true

require 'rails_helper'

describe 'Lexicon entries filtering', :js do
  before do
    login_as_lexicon_editor
  end

  let!(:draft_person) do
    create(:lex_entry, :person, status: :draft, title: 'Draft Person Entry')
  end

  let!(:published_person) do
    create(:lex_entry, :person, status: :published, title: 'Published Person Entry')
  end

  let!(:verified_person) do
    create(:lex_entry, :person, status: :verified, title: 'Verified Person Entry')
  end

  let!(:einstein) do
    create(:lex_entry, :person, status: :published, title: 'Albert Einstein')
  end

  describe 'filtering by status' do
    it 'filters entries by selected status' do
      visit lexicon_entries_path

      # Verify all entries are visible initially
      expect(page).to have_content('Draft Person Entry')
      expect(page).to have_content('Published Person Entry')
      expect(page).to have_content('Verified Person Entry')
      expect(page).to have_content('Albert Einstein')

      # Select "draft" from the status dropdown
      select I18n.t('activerecord.attributes.lex_entry.statuses.draft'), from: I18n.t('lexicon.entries.index.filter_status')

      # Click the filter button
      click_button I18n.t('lexicon.entries.index.filter')

      # Verify only draft entries are visible
      expect(page).to have_content('Draft Person Entry')
      expect(page).not_to have_content('Published Person Entry')
      expect(page).not_to have_content('Verified Person Entry')
      expect(page).not_to have_content('Albert Einstein')
    end

    it 'filters entries by published status' do
      visit lexicon_entries_path

      # Select "published" from the status dropdown
      select I18n.t('activerecord.attributes.lex_entry.statuses.published'), from: I18n.t('lexicon.entries.index.filter_status')

      # Click the filter button
      click_button I18n.t('lexicon.entries.index.filter')

      # Verify only published entries are visible
      expect(page).to have_content('Published Person Entry')
      expect(page).to have_content('Albert Einstein')
      expect(page).not_to have_content('Draft Person Entry')
      expect(page).not_to have_content('Verified Person Entry')
    end
  end

  describe 'filtering by title substring' do
    it 'filters entries by title containing search term' do
      visit lexicon_entries_path

      # Verify all entries are visible initially
      expect(page).to have_content('Draft Person Entry')
      expect(page).to have_content('Published Person Entry')
      expect(page).to have_content('Verified Person Entry')
      expect(page).to have_content('Albert Einstein')

      # Fill in title search field
      fill_in I18n.t('lexicon.entries.index.filter_title'), with: 'Einstein'

      # Click the filter button
      click_button I18n.t('lexicon.entries.index.filter')

      # Verify only matching entries are visible
      expect(page).to have_content('Albert Einstein')
      expect(page).not_to have_content('Draft Person Entry')
      expect(page).not_to have_content('Published Person Entry')
      expect(page).not_to have_content('Verified Person Entry')
    end

    it 'performs case-insensitive search' do
      visit lexicon_entries_path

      # Fill in title search field with mixed case
      fill_in I18n.t('lexicon.entries.index.filter_title'), with: 'PeRsOn'

      # Click the filter button
      click_button I18n.t('lexicon.entries.index.filter')

      # Verify all entries with "Person" in title are visible
      expect(page).to have_content('Draft Person Entry')
      expect(page).to have_content('Published Person Entry')
      expect(page).to have_content('Verified Person Entry')
      expect(page).not_to have_content('Albert Einstein')
    end
  end

  describe 'filtering by both status and title' do
    it 'applies both filters together' do
      visit lexicon_entries_path

      # Fill in title search field
      fill_in I18n.t('lexicon.entries.index.filter_title'), with: 'Person'

      # Select "published" from the status dropdown
      select I18n.t('activerecord.attributes.lex_entry.statuses.published'), from: I18n.t('lexicon.entries.index.filter_status')

      # Click the filter button
      click_button I18n.t('lexicon.entries.index.filter')

      # Verify only entries matching both filters are visible
      expect(page).to have_content('Published Person Entry')
      expect(page).not_to have_content('Draft Person Entry')
      expect(page).not_to have_content('Verified Person Entry')
      expect(page).not_to have_content('Albert Einstein')
    end
  end

  describe 'clearing filters' do
    it 'clears all filters and shows all entries' do
      visit lexicon_entries_path

      # Apply filters
      fill_in I18n.t('lexicon.entries.index.filter_title'), with: 'Person'
      select I18n.t('activerecord.attributes.lex_entry.statuses.draft'), from: I18n.t('lexicon.entries.index.filter_status')
      click_button I18n.t('lexicon.entries.index.filter')

      # Verify filtered results
      expect(page).to have_content('Draft Person Entry')
      expect(page).not_to have_content('Albert Einstein')

      # Click clear filters link
      click_link I18n.t('lexicon.entries.index.clear_filters')

      # Verify all entries are visible again
      expect(page).to have_content('Draft Person Entry')
      expect(page).to have_content('Published Person Entry')
      expect(page).to have_content('Verified Person Entry')
      expect(page).to have_content('Albert Einstein')

      # Verify filters are cleared
      expect(page).to have_field(I18n.t('lexicon.entries.index.filter_title'), with: '')
      expect(page).to have_select(I18n.t('lexicon.entries.index.filter_status'), selected: I18n.t('lexicon.entries.index.all_statuses'))
    end
  end
end
