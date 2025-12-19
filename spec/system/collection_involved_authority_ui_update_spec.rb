# frozen_string_literal: true

require 'rails_helper'

# Check if WebDriver is available before loading the suite
def webdriver_available?
  return @webdriver_available if defined?(@webdriver_available)

  @webdriver_available = begin
    # Try to access the WebDriver to see if it's configured
    driver = Capybara.current_session.driver
    if driver.respond_to?(:browser)
      driver.browser
      true
    else
      true  # Non-Selenium driver, assume it works
    end
  rescue Selenium::WebDriver::Error::WebDriverError,
         Selenium::WebDriver::Error::UnknownError,
         Net::ReadTimeout,
         Errno::ECONNREFUSED,
         StandardError
    false
  end
end

RSpec.describe 'Collection involved authority UI update', type: :system, js: true do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  let!(:authority) do
    Chewy.strategy(:atomic) do
      create(:authority, name: 'Test Author')
    end
  end

  let!(:collection) do
    Chewy.strategy(:atomic) do
      # Create collection without any involved authorities
      create(:collection, title: 'Test Collection')
    end
  end

  after do
    Chewy.massacre
  end

  describe 'adding first involved authority to collection' do
    it 'updates the UI immediately without page refresh' do
      # Log in as editor
      login_as_catalog_editor

      # Visit collection management page
      visit collection_manage_path(collection)

      # Click the edit button to show the editing form
      find('.editcolbutton').click

      # Verify the list container exists (even though empty initially)
      list_id = "involved_authorities_Collection_#{collection.id}"
      expect(page).to have_css("ul##{list_id}", wait: 5)

      # Initially the list should be empty
      within("ul##{list_id}") do
        expect(page).not_to have_css('li')
      end

      # Fill in the authority autocomplete field
      autocomplete_field = find("input[id$='_autocomplete']", match: :first)
      autocomplete_field.fill_in with: authority.name

      # Wait for autocomplete dropdown and select the authority
      find('.ui-autocomplete li.ui-menu-item', text: authority.name, wait: 5).click

      # Select a role - select the first available option
      role_select = find("select[id$='_role']")
      role_select.find('option', match: :first).select_option

      # Click the add button
      click_button I18n.t(:perform_add)

      # Wait for AJAX to complete and verify the authority appears in the list
      within("ul##{list_id}", wait: 10) do
        expect(page).to have_css('li', count: 1)
        expect(page).to have_link('Test Author')
      end

      # Verify we didn't need a page refresh (check URL hasn't changed)
      expect(current_path).to eq(collection_manage_path(collection))
    end
  end

  describe 'adding second involved authority to collection' do
    let!(:collection) do
      Chewy.strategy(:atomic) do
        col = create(:collection, title: 'Test Collection')
        # Add one involved authority initially
        create(:involved_authority, item: col, authority: authority, role: 'editor')
        col
      end
    end

    let!(:second_authority) do
      Chewy.strategy(:atomic) do
        create(:authority, name: 'Second Author')
      end
    end

    it 'updates the UI to show both authorities' do
      # Log in as editor
      login_as_catalog_editor

      # Visit collection management page
      visit collection_manage_path(collection)

      # Click the edit button to show the editing form
      find('.editcolbutton').click

      list_id = "involved_authorities_Collection_#{collection.id}"

      # Initially should have one authority
      within("ul##{list_id}", wait: 5) do
        expect(page).to have_css('li', count: 1)
        expect(page).to have_link('Test Author')
      end

      # Fill in the authority autocomplete field for second authority
      autocomplete_field = find("input[id$='_autocomplete']", match: :first)
      autocomplete_field.fill_in with: second_authority.name

      # Wait for autocomplete dropdown and select the authority
      find('.ui-autocomplete li.ui-menu-item', text: second_authority.name, wait: 5).click

      # Select a role - select the first available option
      role_select = find("select[id$='_role']")
      role_select.find('option', match: :first).select_option

      # Click the add button
      click_button I18n.t(:perform_add)

      # Wait for AJAX to complete and verify both authorities appear
      within("ul##{list_id}", wait: 10) do
        expect(page).to have_css('li', count: 2)
        expect(page).to have_link('Test Author')
        expect(page).to have_link('Second Author')
      end
    end
  end
end
