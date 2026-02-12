# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ingestible advanced collection search', :js, :system do
  let!(:authority1) { create(:authority, :published, name: 'יהודה עמיחי') }
  let!(:authority2) { create(:authority, :published, name: 'לאה גולדברג') }

  let!(:volume1) do
    create(:collection, collection_type: :volume, title: 'שירי הלל')
  end

  let!(:volume2) do
    create(:collection, collection_type: :volume, title: 'שירי אהבה')
  end

  let!(:periodical) do
    create(:collection, collection_type: :periodical, title: 'העת')
  end

  let!(:series) do
    create(:collection, collection_type: :series, title: 'סדרת מסות')
  end

  before do
    # Associate authority1 with volume1
    create(:involved_authority, authority: authority1, item: volume1, role: :author)
    # Associate authority2 with periodical
    create(:involved_authority, authority: authority2, item: periodical, role: :editor)

    # Login as catalog editor
    login_as_catalog_editor

    # Index authorities for autocomplete
    Chewy.strategy(:atomic) do
      AuthoritiesAutocompleteIndex.import!([authority1, authority2])
    end
  end

  after do
    Chewy.massacre
  end

  describe 'widget visibility' do
    it 'shows the advanced search toggle button' do
      visit new_ingestible_path

      # Click to expand volume details if hidden
      begin
        find('#change_volume', wait: 5).click
      rescue Capybara::ElementNotFound
        # Volume details already visible
      end

      expect(page).to have_button(I18n.t('ingestible.advanced_collection_search'), wait: 5)
    end

    it 'toggles widget visibility when button is clicked' do
      visit new_ingestible_path

      # Expand volume details
      begin
        find('#change_volume', wait: 5).click
      rescue Capybara::ElementNotFound
        # Volume details already visible
      end

      # Initially hidden
      expect(page).to have_css('#advanced_collection_search', visible: false, wait: 5)

      # Click toggle button
      find('#toggle_advanced_search', wait: 5).click

      # Should be visible
      expect(page).to have_css('#advanced_collection_search', visible: true, wait: 5)

      # Click again
      find('#toggle_advanced_search', wait: 5).click

      # Should be hidden
      expect(page).to have_css('#advanced_collection_search', visible: false, wait: 5)
    end
  end

  describe 'searching by title' do
    it 'finds collections matching title substring' do
      visit new_ingestible_path

      # Expand volume details and show advanced search
      begin
        find('#change_volume', wait: 5).click
      rescue Capybara::ElementNotFound
        # Volume details already visible
      end

      find('#toggle_advanced_search', wait: 5).click
      expect(page).to have_css('#advanced_collection_search', visible: true, wait: 5)

      # Search by title
      fill_in 'advanced_search_title', with: 'שירי'
      find('#advanced_search_button', wait: 5).click

      # Should show results
      expect(page).to have_css('.advanced-search-result', count: 2, wait: 5)
      expect(page).to have_content('שירי הלל', wait: 5)
      expect(page).to have_content('שירי אהבה', wait: 5)
    end

    it 'shows no results message when no matches' do
      visit new_ingestible_path

      begin
        find('#change_volume', wait: 5).click
      rescue Capybara::ElementNotFound
        # Volume details already visible
      end

      find('#toggle_advanced_search', wait: 5).click
      expect(page).to have_css('#advanced_collection_search', visible: true, wait: 5)

      # Search with non-matching term
      fill_in 'advanced_search_title', with: 'nonexistent'
      find('#advanced_search_button', wait: 5).click

      # Should show no results message
      expect(page).to have_content(I18n.t('ingestible.no_results'), wait: 5)
    end
  end

  describe 'searching by collection type' do
    it 'filters by selected collection types' do
      visit new_ingestible_path

      begin
        find('#change_volume', wait: 5).click
      rescue Capybara::ElementNotFound
        # Volume details already visible
      end

      find('#toggle_advanced_search', wait: 5).click
      expect(page).to have_css('#advanced_collection_search', visible: true, wait: 5)

      # Select only volume type
      check 'collection_type_volume', wait: 5
      find('#advanced_search_button', wait: 5).click

      # Should show only volumes
      expect(page).to have_css('.advanced-search-result', count: 2, wait: 5)

      # Check within results div specifically
      within('#advanced_search_results', wait: 5) do
        expect(page).to have_content('שירי הלל')
        expect(page).to have_content('שירי אהבה')
        expect(page).not_to have_content('העת')
        expect(page).not_to have_content('סדרת מסות')
      end
    end

    it 'allows multiple type selection' do
      visit new_ingestible_path

      begin
        find('#change_volume', wait: 5).click
      rescue Capybara::ElementNotFound
        # Volume details already visible
      end

      find('#toggle_advanced_search', wait: 5).click
      expect(page).to have_css('#advanced_collection_search', visible: true, wait: 5)

      # Select volume and periodical types
      check 'collection_type_volume', wait: 5
      check 'collection_type_periodical', wait: 5
      find('#advanced_search_button', wait: 5).click

      # Should show volumes and periodical
      expect(page).to have_css('.advanced-search-result', count: 3, wait: 5)
    end
  end

  describe 'searching by authority' do
    it 'finds collections associated with authority' do
      visit new_ingestible_path

      begin
        find('#change_volume', wait: 5).click
      rescue Capybara::ElementNotFound
        # Volume details already visible
      end

      find('#toggle_advanced_search', wait: 5).click
      expect(page).to have_css('#advanced_collection_search', visible: true, wait: 5)

      # Type authority name in autocomplete
      fill_in 'advanced_search_authority', with: 'יהודה'

      # Wait for autocomplete results
      expect(page).to have_css('.ui-autocomplete', visible: true, wait: 5)

      # Click on the autocomplete result
      within('.ui-autocomplete', wait: 5) do
        find('li', text: 'יהודה עמיחי', wait: 5).click
      end

      # Results should appear automatically after authority selection
      expect(page).to have_css('.advanced-search-result', count: 1, wait: 5)
      expect(page).to have_content('שירי הלל', wait: 5)
    end
  end

  describe 'combining filters' do
    it 'applies all filters together' do
      visit new_ingestible_path

      begin
        find('#change_volume', wait: 5).click
      rescue Capybara::ElementNotFound
        # Volume details already visible
      end

      find('#toggle_advanced_search', wait: 5).click
      expect(page).to have_css('#advanced_collection_search', visible: true, wait: 5)

      # Search by title AND type
      fill_in 'advanced_search_title', with: 'שירי'
      check 'collection_type_volume', wait: 5
      find('#advanced_search_button', wait: 5).click

      # Should find both volumes with 'שירי' in title
      expect(page).to have_css('.advanced-search-result', count: 2, wait: 5)
    end
  end

  describe 'selecting a result' do
    it 'sets the selected collection and hides the widget' do
      visit new_ingestible_path

      begin
        find('#change_volume', wait: 5).click
      rescue Capybara::ElementNotFound
        # Volume details already visible
      end

      find('#toggle_advanced_search', wait: 5).click
      expect(page).to have_css('#advanced_collection_search', visible: true, wait: 5)

      # Search and get results
      fill_in 'advanced_search_title', with: 'שירי הלל'
      find('#advanced_search_button', wait: 5).click

      expect(page).to have_css('.advanced-search-result', wait: 5)

      # Click on the result
      find('.advanced-search-result', text: 'שירי הלל', wait: 5).click

      # Widget should hide
      expect(page).to have_css('#advanced_collection_search', visible: false, wait: 5)

      # Autocomplete field should be populated with selected collection title
      expect(find('#cterm', wait: 5).value).to eq('שירי הלל')

      # Hidden prospective_volume_id should be set
      expect(find('#prospective_volume_id', visible: false).value).to eq(volume1.id.to_s)

      # The "create new volume" field should be EMPTY (we're selecting existing, not creating new)
      expect(find('#ingestible_prospective_volume_title', visible: false).value).to be_empty

      # no_volume checkbox should be unchecked
      expect(find('#ingestible_no_volume', visible: false)).not_to be_checked

      # Save notice should appear
      expect(page).to have_css('#need_to_save', visible: true, wait: 5)
    end
  end
end
