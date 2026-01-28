# frozen_string_literal: true

require 'rails_helper'

describe 'Bib Shopping List Pagination' do
  let(:editor_user) { create(:user, :bib_workshop) }
  let(:bib_source) { create(:bib_source) }

  def login_as_editor
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(editor_user)
    editor_user
  end

  describe 'pagination with more than 50 holdings' do
    before do
      login_as_editor

      # Create 75 holdings for the same bib source with status 'todo'
      # Each holding is for a different publication to test de-duplication
      75.times do |i|
        publication = create(:publication,
                             title: "Test Publication #{i}",
                             status: :todo,
                             bib_source: bib_source)
        create(:holding,
               publication: publication,
               bib_source: bib_source,
               status: :todo,
               location: "Shelf #{i}")
      end
    end

    it 'displays pagination controls when there are more than 50 results' do
      visit bib_shopping_path(source_id: bib_source.id)

      # Should show pagination controls
      expect(page).to have_css('.pagination')

      # Should have page entries info (works in both Hebrew and English)
      expect(page).to have_css('.page_entries_info')
      # Check for pagination links
      expect(page).to have_link(I18n.t('views.pagination.next'))
    end

    it 'shows 50 items on the first page' do
      visit bib_shopping_path(source_id: bib_source.id)

      # Count the number of table rows (excluding header)
      rows = page.all('table tr').count - 1 # Subtract header row
      expect(rows).to eq(50)
    end

    it 'allows navigation to the next page' do
      visit bib_shopping_path(source_id: bib_source.id)

      # Get the first publication title on page 1
      first_title_page1 = page.first('table tr:nth-child(2) td:first-child').text

      # Click next page (use first pagination controls to avoid ambiguity)
      first('.pagination').click_link(I18n.t('views.pagination.next'))

      # Wait for page to load
      expect(page).to have_css('table tr')

      # The first title on page 2 should be different
      first_title_page2 = page.first('table tr:nth-child(2) td:first-child').text
      expect(first_title_page2).not_to eq(first_title_page1)
    end

    it 'shows remaining items on the last page' do
      visit bib_shopping_path(source_id: bib_source.id, page: 2)

      # Should show 25 items on page 2 (75 total - 50 on page 1)
      rows = page.all('table tr').count - 1 # Subtract header row
      expect(rows).to eq(25)
    end
  end

  describe 'pagination with 50 or fewer holdings' do
    before do
      login_as_editor

      # Create exactly 30 holdings
      30.times do |i|
        publication = create(:publication,
                             title: "Small Set Publication #{i}",
                             status: :todo,
                             bib_source: bib_source)
        create(:holding,
               publication: publication,
               bib_source: bib_source,
               status: :todo,
               location: "Shelf #{i}")
      end
    end

    it 'does not show pagination controls when there are 50 or fewer results' do
      visit bib_shopping_path(source_id: bib_source.id)

      # Should not show pagination controls (or should show as disabled/single page)
      # Kaminari typically doesn't render pagination for single page
      expect(page).not_to have_css('.pagination a')
    end

    it 'shows all items on a single page' do
      visit bib_shopping_path(source_id: bib_source.id)

      rows = page.all('table tr').count - 1 # Subtract header row
      expect(rows).to eq(30)
    end
  end

  describe 'de-duplication of publications' do
    before do
      login_as_editor

      # Create one publication with 3 holdings in the same source
      # Make sure the publication has authority to avoid validation issues
      authority = create(:authority)
      publication = create(:publication,
                           title: 'Duplicate Test Publication',
                           authority: authority,
                           status: :todo,
                           bib_source: bib_source)

      3.times do |i|
        create(:holding,
               publication: publication,
               bib_source: bib_source,
               status: :todo,
               location: "Dup Location #{i}")
      end

      # Create 50 more unique publications to test pagination with duplicates
      50.times do |i|
        auth = create(:authority)
        pub = create(:publication,
                     title: "Unique Publication #{i}",
                     authority: auth,
                     status: :todo,
                     bib_source: bib_source)
        create(:holding,
               publication: pub,
               bib_source: bib_source,
               status: :todo,
               location: "Location #{i}")
      end
    end

    it 'only displays each publication once' do
      visit bib_shopping_path(source_id: bib_source.id)

      # Count the number of table rows with the duplicate publication title
      # Search for links containing the title text
      duplicate_rows = page.all('table tr').select do |row|
        row.text.include?('Duplicate Test Publication')
      end

      # Should appear only once in the table
      expect(duplicate_rows.count).to eq(1)
    end
  end

  describe 'filters work with pagination', js: true do
    before do
      login_as_editor

      # Create 60 public domain publications
      60.times do |i|
        authority = create(:authority, intellectual_property: :public_domain)
        publication = create(:publication,
                             title: "PD Publication #{i}",
                             authority: authority,
                             status: :todo,
                             bib_source: bib_source)
        create(:holding,
               publication: publication,
               bib_source: bib_source,
               status: :todo)
      end

      # Create 30 non-public domain publications
      30.times do |i|
        authority = create(:authority, intellectual_property: :copyrighted)
        publication = create(:publication,
                             title: "Non-PD Publication #{i}",
                             authority: authority,
                             status: :todo,
                             bib_source: bib_source)
        create(:holding,
               publication: publication,
               bib_source: bib_source,
               status: :todo)
      end
    end

    it 'applies public domain filter with pagination' do
      visit bib_shopping_path(source_id: bib_source.id)

      # Apply PD filter
      check 'pd'
      click_button I18n.t(:filter)

      # Should show pagination for 60 PD items
      expect(page).to have_css('.pagination')

      # First page should show 50 items
      rows = page.all('table tr').count - 1
      expect(rows).to eq(50)

      # All visible titles should be PD publications
      expect(page).to have_content('PD Publication')
      expect(page).not_to have_content('Non-PD Publication')
    end
  end

  describe 'authentication required' do
    it 'redirects non-authenticated users' do
      # Don't log in
      visit bib_shopping_path(source_id: bib_source.id)

      # Should be redirected (exact behavior depends on auth system)
      expect(page).not_to have_css('table')
    end
  end
end
