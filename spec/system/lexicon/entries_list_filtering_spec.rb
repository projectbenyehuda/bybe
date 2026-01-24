# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Lexicon entries list filtering', type: :system, js: true do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  let!(:person_male) do
    entry = create(:lex_entry, :person, status: :published, title: 'אברהם')
    entry.lex_item.update!(gender: :male, birthdate: '1850', deathdate: '1920')
    entry
  end

  let!(:person_female) do
    entry = create(:lex_entry, :person, status: :published, title: 'שרה')
    entry.lex_item.update!(gender: :female, birthdate: '1900', deathdate: '1980')
    entry
  end

  let!(:publication_entry) do
    create(:lex_entry, :publication, status: :published, title: 'העתון')
  end

  before do
    visit lexicon_entries_list_path
  end

  describe 'filter form' do
    it 'loads the filter panel elements' do
      # Check that filter fields are present in the DOM (even if collapsed)
      expect(page).to have_selector('#name_filter', visible: :all)
      expect(page).to have_selector('#birth_year_from', visible: :all)
      expect(page).to have_selector('#birth_year_to', visible: :all)
      expect(page).to have_selector('#death_year_from', visible: :all)
      expect(page).to have_selector('#death_year_to', visible: :all)
    end
  end

  describe 'name filter' do
    it 'filters entries by name via AJAX' do
      # Initial state: all entries visible
      expect(page).to have_content('אברהם')
      expect(page).to have_content('שרה')
      expect(page).to have_content('העתון')

      # Enter name filter
      fill_in 'name_filter', with: 'שרה'

      # Wait for AJAX to complete
      expect(page).to have_content('שרה')
      expect(page).not_to have_content('אברהם')
      expect(page).not_to have_content('העתון')
    end

    it 'shows filter pill for name filter' do
      fill_in 'name_filter', with: 'שרה'

      expect(page).to have_css('.filters .tag', text: /שם מכיל.*שרה/)
    end
  end

  describe 'gender filter' do
    it 'filters by gender via AJAX' do
      # Check female gender checkbox
      check 'gender_female'

      # Wait for AJAX
      expect(page).to have_content('שרה')
      expect(page).not_to have_content('אברהם')
      expect(page).not_to have_content('העתון')
    end

    it 'shows filter pill for gender filter' do
      check 'gender_female'

      expect(page).to have_css('.filters .tag', text: I18n.t('lexicon.entries.list.filters.gender_female'))
    end

    it 'hides publication entries when gender filter active' do
      # Initially publication is visible
      expect(page).to have_content('העתון')

      # Apply gender filter
      check 'gender_male'

      # Publication should be hidden
      expect(page).not_to have_content('העתון')
    end
  end

  describe 'birth year filter' do
    it 'filters by birth year range via AJAX' do
      fill_in 'birth_year_from', with: '1875'
      fill_in 'birth_year_to', with: '1925'

      # Wait for AJAX
      expect(page).to have_content('שרה') # born 1900
      expect(page).not_to have_content('אברהם') # born 1850
      expect(page).not_to have_content('העתון')
    end

    it 'shows filter pills for birth year range' do
      fill_in 'birth_year_from', with: '1875'
      fill_in 'birth_year_to', with: '1925'

      expect(page).to have_css('.filters .tag', text: /נולד משנת.*1875/)
      expect(page).to have_css('.filters .tag', text: /נולד עד שנת.*1925/)
    end
  end

  describe 'death year filter' do
    it 'filters by death year range via AJAX' do
      fill_in 'death_year_from', with: '1950'
      fill_in 'death_year_to', with: '1990'

      # Wait for AJAX
      expect(page).to have_content('שרה') # died 1980
      expect(page).not_to have_content('אברהם') # died 1920
      expect(page).not_to have_content('העתון')
    end

    it 'shows filter pills for death year range' do
      fill_in 'death_year_from', with: '1950'

      expect(page).to have_css('.filters .tag', text: /נפטר משנת.*1950/)
    end
  end

  describe 'filter pill removal' do
    it 'removes filter when clicking pill X' do
      # Apply filter
      fill_in 'name_filter', with: 'שרה'
      expect(page).to have_css('.filters .tag')

      # Click X on pill
      find('.filters .tag .tag-x').click

      # Filter should be removed, all entries visible again
      expect(page).to have_content('אברהם')
      expect(page).to have_content('שרה')
      expect(page).to have_content('העתון')
      expect(page).not_to have_css('.filters .tag')
    end
  end

  describe 'reset button' do
    it 'clears all filters when clicked' do
      # Apply multiple filters
      fill_in 'name_filter', with: 'שרה'
      check 'gender_female'
      fill_in 'birth_year_from', with: '1875'

      # Verify filters are applied
      expect(page).to have_css('.filters .tag', count: 3)

      # Click reset
      find('.reset').click

      # All filters should be cleared
      expect(page).not_to have_css('.filters .tag')
      expect(page).to have_content('אברהם')
      expect(page).to have_content('שרה')
      expect(page).to have_content('העתון')
    end
  end

  describe 'sorting with filters' do
    it 'preserves filters when changing sort order' do
      # Apply filter
      check 'gender_female'
      expect(page).to have_content('שרה')
      expect(page).not_to have_content('אברהם')

      # Change sort order
      select I18n.t(:birthdate_desc), from: 'sort_by_select'

      # Filter should still be active
      expect(page).to have_content('שרה')
      expect(page).not_to have_content('אברהם')
      expect(page).to have_css('.filters .tag', text: I18n.t('lexicon.entries.list.filters.gender_female'))
    end
  end

  describe 'combined filters' do
    it 'applies multiple filters together' do
      # Apply name, gender, and year filters
      fill_in 'name_filter', with: 'שרה'
      check 'gender_female'
      fill_in 'birth_year_from', with: '1875'

      # Should show only matching entry
      expect(page).to have_content('שרה')
      expect(page).not_to have_content('אברהם')
      expect(page).not_to have_content('העתון')

      # Should show all filter pills
      expect(page).to have_css('.filters .tag', minimum: 3)
    end
  end

  describe 'permalink' do
    it 'includes all active filters in permalink URL' do
      # Apply filters
      fill_in 'name_filter', with: 'שרה'
      check 'gender_female'

      # Wait for AJAX to complete
      expect(page).to have_css('.filters .tag', minimum: 2)

      # Check permalink href includes filter params
      permalink_link = find('.permalink-btn')
      url = permalink_link['data-url']
      expect(url).to include('name_filter=')
      expect(url).to include('ckb_genders')
    end
  end
end
