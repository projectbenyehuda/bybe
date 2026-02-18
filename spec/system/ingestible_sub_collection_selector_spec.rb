# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ingestible sub-collection selector', :js, :system do
  let!(:parent_volume) do
    create(:collection, collection_type: :volume, title: 'Complete Works')
  end

  let!(:series1) do
    create(:collection, collection_type: :series, title: 'Poetry Series')
  end

  let!(:series2) do
    create(:collection, collection_type: :series, title: 'Prose Series')
  end

  let!(:subseries) do
    create(:collection, collection_type: :series, title: 'Early Poems')
  end

  before do
    # Create hierarchy: parent_volume -> series1 -> subseries
    #                                  -> series2
    create(:collection_item, collection: parent_volume, item: series1)
    create(:collection_item, collection: parent_volume, item: series2)
    create(:collection_item, collection: series1, item: subseries)

    # Login as catalog editor
    login_as_catalog_editor
  end

  describe 'when selecting a collection via autocomplete' do
    it 'shows sub-collections dropdown' do
      visit new_ingestible_path

      # Expand volume details
      begin
        find('#change_volume', wait: 5).click
      rescue Capybara::ElementNotFound
        # Volume details already visible
      end

      # Select parent volume via autocomplete
      fill_in 'volume', with: 'Complete Works'
      expect(page).to have_css('.ui-autocomplete', visible: true, wait: 5)

      within('.ui-autocomplete', wait: 5) do
        find('li', text: 'Complete Works', wait: 5).click
      end

      # Sub-collections dropdown should appear
      expect(page).to have_css('#sub_collection_selector', visible: true, wait: 5)

      # Should list all descendants
      within('#sub_collection_id', wait: 5) do
        expect(page).to have_content('Poetry Series')
        expect(page).to have_content('Prose Series')
        expect(page).to have_content('Early Poems')
      end
    end

    it 'allows selecting a sub-collection' do
      visit new_ingestible_path

      begin
        find('#change_volume', wait: 5).click
      rescue Capybara::ElementNotFound
        # Volume details already visible
      end

      # Select parent volume
      fill_in 'volume', with: 'Complete Works'
      expect(page).to have_css('.ui-autocomplete', visible: true, wait: 5)

      within('.ui-autocomplete', wait: 5) do
        find('li', text: 'Complete Works', wait: 5).click
      end

      # Wait for sub-collections to load
      expect(page).to have_css('#sub_collection_selector', visible: true, wait: 5)

      # Select a sub-collection
      select 'Poetry Series', from: 'sub_collection_id', wait: 5

      # The autocomplete field should now show the sub-collection
      expect(find('#cterm', wait: 5).value).to eq('Poetry Series')

      # The hidden field should have the sub-collection ID
      expect(find('#prospective_volume_id', visible: false).value).to eq(series1.id.to_s)
    end

    it 'hides dropdown when no sub-collections exist' do
      # Create a collection with no children
      create(:collection, collection_type: :volume, title: 'Empty Volume')

      visit new_ingestible_path

      begin
        find('#change_volume', wait: 5).click
      rescue Capybara::ElementNotFound
        # Volume details already visible
      end

      # Select empty collection
      fill_in 'volume', with: 'Empty Volume'
      expect(page).to have_css('.ui-autocomplete', visible: true, wait: 5)

      within('.ui-autocomplete', wait: 5) do
        find('li', text: 'Empty Volume', wait: 5).click
      end

      # Sub-collections dropdown should be hidden
      expect(page).to have_css('#sub_collection_selector', visible: false, wait: 5)
    end
  end

  describe 'when changing collection selection' do
    it 'reloads sub-collections when parent changes' do
      # Create another parent with different children
      another_parent = create(:collection, collection_type: :volume, title: 'Other Works')
      another_series = create(:collection, collection_type: :series, title: 'Essays')
      create(:collection_item, collection: another_parent, item: another_series)

      visit new_ingestible_path

      begin
        find('#change_volume', wait: 5).click
      rescue Capybara::ElementNotFound
        # Volume details already visible
      end

      # Select first parent
      fill_in 'volume', with: 'Complete Works'
      expect(page).to have_css('.ui-autocomplete', visible: true, wait: 5)

      within('.ui-autocomplete', wait: 5) do
        find('li', text: 'Complete Works', match: :first, wait: 5).click
      end

      expect(page).to have_css('#sub_collection_selector', visible: true, wait: 5)

      # Verify first set of sub-collections
      within('#sub_collection_id', wait: 5) do
        expect(page).to have_content('Poetry Series')
      end

      # Change to different parent
      fill_in 'volume', with: 'Other Works'
      expect(page).to have_css('.ui-autocomplete', visible: true, wait: 5)

      within('.ui-autocomplete', wait: 5) do
        find('li', text: 'Other Works', wait: 5).click
      end

      # Should reload with new sub-collections
      within('#sub_collection_id', wait: 5) do
        expect(page).to have_content('Essays')
        expect(page).not_to have_content('Poetry Series')
      end
    end

    it 'hides dropdown when no_volume is checked' do
      visit new_ingestible_path

      begin
        find('#change_volume', wait: 5).click
      rescue Capybara::ElementNotFound
        # Volume details already visible
      end

      # Select a collection first
      fill_in 'volume', with: 'Complete Works'
      expect(page).to have_css('.ui-autocomplete', visible: true, wait: 5)

      within('.ui-autocomplete', wait: 5) do
        find('li', text: 'Complete Works', wait: 5).click
      end

      expect(page).to have_css('#sub_collection_selector', visible: true, wait: 5)

      # Check no_volume
      check 'ingestible_no_volume', wait: 5

      # Dropdown should be hidden
      expect(page).to have_css('#sub_collection_selector', visible: false, wait: 5)
    end

    it 'does not populate prospective_volume_title when selecting existing collection' do
      visit new_ingestible_path

      begin
        find('#change_volume', wait: 5).click
      rescue Capybara::ElementNotFound
        # Volume details already visible
      end

      # Check no_volume first
      check 'ingestible_no_volume', wait: 5

      # Verify prospective_volume_title is empty
      expect(find('#ingestible_prospective_volume_title', wait: 5).value).to eq('')

      # Now select a collection via autocomplete
      fill_in 'volume', with: 'Complete Works'
      expect(page).to have_css('.ui-autocomplete', visible: true, wait: 5)

      within('.ui-autocomplete', wait: 5) do
        find('li', text: 'Complete Works', wait: 5).click
      end

      # The prospective_volume_title field should remain empty
      # (it's for creating NEW volumes, not selecting existing ones)
      expect(find('#ingestible_prospective_volume_title', wait: 5).value).to eq('')

      # But the autocomplete field should show the selection
      expect(find('#cterm', wait: 5).value).to eq('Complete Works')

      # And the no_volume checkbox should be unchecked
      expect(find('#ingestible_no_volume', wait: 5)).not_to be_checked
    end
  end
end
