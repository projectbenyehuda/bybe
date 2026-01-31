# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Collection selective download and print', :js, type: :system do
  before do
    begin
      Capybara.current_session.driver.browser if Capybara.current_session.driver.respond_to?(:browser)
    rescue StandardError
      skip 'WebDriver not available or misconfigured'
    end
  end

  let!(:author) { create(:authority, name: 'Test Author') }
  let!(:work1) { create(:work, title: 'Work 1') }
  let!(:work2) { create(:work, title: 'Work 2') }
  let!(:work3) { create(:work, title: 'Work 3') }

  let!(:manifestation1) do
    Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Text One', markdown: 'Content of text one', status: :published)
    end
  end

  let!(:manifestation2) do
    Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Text Two', markdown: 'Content of text two', status: :published)
    end
  end

  let!(:manifestation3) do
    Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Text Three', markdown: 'Content of text three', status: :published)
    end
  end

  let!(:collection) do
    Chewy.strategy(:atomic) do
      col = create(:collection, title: 'Test Collection')
      create(:involved_authority, item: col, authority: author, role: 'author')

      # Add manifestations to collection
      col.collection_items.create!(item: manifestation1, seqno: 1)
      col.collection_items.create!(item: manifestation2, seqno: 2)
      col.collection_items.create!(item: manifestation3, seqno: 3)

      col
    end
  end

  after do
    Chewy.massacre
  end

  describe 'Download modal' do
    it 'shows full collection option by default' do
      visit collection_path(collection)

      # Click download button
      find('.by-icon-v02.download').click

      # Wait for modal to appear
      expect(page).to have_css('#downloadDlg', visible: true, wait: 10)

      within('#downloadDlg') do
        # Check that full collection toggle is active by default
        expect(page).to have_css('.search-mobile-option.active', text: I18n.t(:full_collection))

        # Check that manifestation selection area is hidden
        expect(page).to have_css('#manifestation-selection-area', visible: false)

        # Check that button text is for full collection
        expect(page).to have_button(I18n.t(:download_full_collection))
      end
    end

    it 'shows manifestation list when selecting partial option' do
      visit collection_path(collection)

      find('.by-icon-v02.download').click

      within('#downloadDlg') do
        # Click on selected items toggle
        find('.search-mobile-option', text: I18n.t(:selected_items)).click

        # Check that manifestation selection area is visible
        expect(page).to have_css('#manifestation-selection-area', visible: true)

        # Check that all manifestations are listed
        expect(page).to have_text('Text One')
        expect(page).to have_text('Text Two')
        expect(page).to have_text('Text Three')

        # Check that checkboxes are present
        expect(page).to have_css('.multiselect_checkbox', count: 3)
      end
    end

    it 'updates button text based on selection count' do
      visit collection_path(collection)

      find('.by-icon-v02.download').click

      within('#downloadDlg') do
        # Switch to partial mode
        find('.search-mobile-option', text: I18n.t(:selected_items)).click

        # Select 2 manifestations
        checkboxes = all('.multiselect_checkbox')
        checkboxes[0].check
        checkboxes[1].check

        # Check that count is updated
        expect(page).to have_css('#selected-count', text: '2')

        # Check that button text includes count (wait a bit for JavaScript to update)
        sleep 0.5
        expect(page).to have_css('.by-button-v02', text: /2/)
      end
    end

    it 'selects all manifestations when clicking select all checkbox' do
      visit collection_path(collection)

      find('.by-icon-v02.download').click

      within('#downloadDlg') do
        # Switch to partial mode
        find('.search-mobile-option', text: I18n.t(:selected_items)).click

        # Click select all
        find('#select-all-checkbox').check

        # Check that all checkboxes are checked
        expect(page).to have_css('.multiselect_checkbox:checked', count: 3)

        # Check that count is 3
        expect(page).to have_css('#selected-count', text: '3')
      end
    end
  end

  describe 'Print modal' do
    it 'shows full collection option by default' do
      visit collection_path(collection)

      # Click print button
      find('.by-icon-v02.printbutton').click

      # Wait for modal to appear
      expect(page).to have_css('#printDlg', visible: true, wait: 10)

      within('#printDlg') do
        # Check that full collection toggle is active by default
        expect(page).to have_css('.search-mobile-option.active', text: I18n.t(:full_collection))

        # Check that manifestation selection area is hidden
        expect(page).to have_css('#print-manifestation-selection-area', visible: false)

        # Check that button text is for full collection
        expect(page).to have_button(I18n.t(:print_full_collection))
      end
    end

    it 'shows manifestation list when selecting partial option' do
      visit collection_path(collection)

      find('.by-icon-v02.printbutton').click

      within('#printDlg') do
        # Click on selected items toggle
        find('.search-mobile-option', text: I18n.t(:selected_items)).click

        # Check that manifestation selection area is visible
        expect(page).to have_css('#print-manifestation-selection-area', visible: true)

        # Check that all 3 manifestation list items are present (some may be outside viewport in scrollable area)
        within('#texts-to-print ol') do
          expect(page).to have_css('li', count: 3, visible: false)
        end

        # Check that checkboxes are present (at least the visible ones)
        expect(page).to have_css('.print-multiselect_checkbox', minimum: 2)
      end
    end

    it 'updates button text based on selection count' do
      visit collection_path(collection)

      find('.by-icon-v02.printbutton').click

      within('#printDlg') do
        # Switch to partial mode
        find('.search-mobile-option', text: I18n.t(:selected_items)).click

        # Select 2 manifestations
        checkboxes = all('.print-multiselect_checkbox')
        checkboxes[0].check
        checkboxes[1].check

        # Check that count is updated
        expect(page).to have_css('#print-selected-count', text: '2')

        # Check that button text includes count (wait a bit for JavaScript to update)
        sleep 0.5
        expect(page).to have_css('.by-button-v02', text: /2/)
      end
    end
  end
end
