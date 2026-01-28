# frozen_string_literal: true

require 'rails_helper'

describe 'Ingestible autocomplete scrollable' do
  let!(:authorities) do
    Chewy.strategy(:atomic) do
      # Create more than 10 authorities to test that all are returned
      15.times.map do |i|
        create(:authority, name: "Test Author #{i.to_s.rjust(2, '0')}")
      end
    end
  end

  let!(:collections) do
    Chewy.strategy(:atomic) do
      # Create more than 10 collections to test that all are returned
      15.times.map do |i|
        create(:collection, title: "Test Collection #{i.to_s.rjust(2, '0')}")
      end
    end
  end

  before do
    # Login as catalog editor
    login_as_catalog_editor
  end

  after do
    Chewy.massacre
  end

  describe 'authority autocomplete', js: true do
    it 'returns all matching results (more than 10)' do
      visit new_ingestible_path

      # Click to expand volume details if hidden
      begin
        find('#change_volume').click
        sleep 0.5 # Allow animation to complete
      rescue Capybara::ElementNotFound
        # Volume details already visible
      end

      # Type in the author autocomplete field
      fill_in 'author', with: 'Test Author'

      # Wait for autocomplete results to appear
      expect(page).to have_css('.ui-autocomplete', visible: true, wait: 5)

      # Count the number of autocomplete items
      # There should be more than 10 (all 15 matching authors)
      autocomplete_items = all('.ui-autocomplete li.ui-menu-item', wait: 5)
      expect(autocomplete_items.count).to be >= 11
    end

    it 'has scrollable CSS class applied' do
      visit new_ingestible_path

      # Click to expand volume details if hidden
      begin
        find('#change_volume').click
      rescue Capybara::ElementNotFound
        # Volume details already visible
      end

      # The input field should have the correct class
      expect(page).to have_css('#aterm.ingestible-autocomplete-author')
    end
  end

  describe 'collection autocomplete' do
    it 'returns all matching results (more than 10)', js: true do
      visit new_ingestible_path

      # Click to expand volume details if hidden
      begin
        find('#change_volume').click
        sleep 0.5 # Allow animation to complete
      rescue Capybara::ElementNotFound
        # Volume details already visible
      end

      # Type in the volume autocomplete field
      fill_in 'volume', with: 'Test Collection'

      # Wait for autocomplete results
      expect(page).to have_css('.ui-autocomplete', visible: true, wait: 5)

      # Count the number of autocomplete items
      # There should be more than 10 (all 15 matching collections)
      autocomplete_items = all('.ui-autocomplete li.ui-menu-item', wait: 5)
      expect(autocomplete_items.count).to be >= 11
    end

    it 'has scrollable CSS class applied' do
      visit new_ingestible_path

      # Click to expand volume details if hidden
      begin
        find('#change_volume').click
      rescue Capybara::ElementNotFound
        # Volume details already visible
      end

      # The input field should have the correct class
      expect(page).to have_css('#cterm.ingestible-autocomplete-volume')
    end
  end
end
