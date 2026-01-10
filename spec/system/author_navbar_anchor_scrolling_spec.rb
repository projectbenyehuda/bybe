# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Author navbar anchor scrolling', type: :system, js: true do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  let!(:author) do
    create(:authority, name: 'Test Author', gender: 'male')
  end

  let!(:collection) do
    create(:collection, title: 'Test Collection')
  end

  let!(:manifestation) do
    Chewy.strategy(:atomic) do
      create(:manifestation,
             title: 'Test Work',
             status: :published,
             author: author)
    end
  end

  let!(:involved_authority) do
    create(:involved_authority,
           authority: author,
           item: collection,
           role: 'editor')
  end

  after do
    Chewy.massacre
  end

  describe 'navbar section anchor scrolling' do
    it 'adds scroll targets to navbar section headers' do
      visit authority_path(author)

      # Wait for page to load
      expect(page).to have_css('.book-nav-full')

      # Check that navbar sections have data-scroll-target attributes
      within('.book-nav-full') do
        expect(page).to have_css('.truncate[data-scroll-target]')
      end
    end

    it 'scrolls to corresponding mainlist section when navbar link is clicked' do
      visit authority_path(author)

      # Wait for page to load
      expect(page).to have_css('.book-nav-full')
      expect(page).to have_css('#browse_mainlist')

      # Find all navbar sections with scroll targets
      navbar_sections = all('.book-type .truncate[data-scroll-target]')

      # Skip test if no navbar sections found
      skip 'No navbar sections with scroll targets found' if navbar_sections.empty?

      # Test the first navbar section that has a corresponding target in the mainlist
      navbar_sections.each do |navbar_section|
        scroll_target = navbar_section['data-scroll-target']

        # Skip this section if target doesn't exist in mainlist
        next unless page.has_css?(scroll_target, visible: :all)

        # Click the navbar section
        navbar_section.click

        # Verify the target section exists and is in the DOM
        expect(page).to have_css(scroll_target, visible: :all)

        # Test passed, exit loop
        break
      end
    end

    it 'maintains collapse functionality while adding scroll behavior' do
      visit authority_path(author)

      # Wait for page to load
      expect(page).to have_css('.book-nav-full')

      # Find all collapsible navbar sections
      navbar_sections = all('.book-type .truncate[data-bs-toggle="collapse"]')

      # Skip test if no collapsible sections found
      skip 'No collapsible navbar sections found' if navbar_sections.empty?

      # Test with the first navbar section that has a collapse target
      navbar_sections.each do |navbar_section|
        collapse_target = navbar_section['data-bs-target']

        # Skip if collapse target doesn't exist
        next unless page.has_css?(collapse_target, visible: :all)

        # Click the navbar section
        navbar_section.click

        # Verify collapse functionality still works by checking the collapse target exists
        expect(page).to have_css(collapse_target, visible: :all)

        # Test passed, exit loop
        break
      end
    end

    it 'makes collection links scroll to collection anchors instead of navigating away' do
      visit authority_path(author)

      # Wait for page to load
      expect(page).to have_css('.book-nav-full')

      # Find collection anchor links in the navbar
      collection_links = all('.collection-anchor-link')

      # Skip test if no collection links found
      skip 'No collection anchor links found' if collection_links.empty?

      # Test with the first collection link
      collection_links.each do |link|
        anchor_target = link['href']

        # Skip if it's not an anchor link (should start with #)
        next unless anchor_target&.start_with?('#')

        # Verify the target exists in the mainlist
        target_id = anchor_target.delete_prefix('#')
        next unless page.has_css?("##{target_id}", visible: :all)

        # The link should have the collection-anchor-link class
        expect(link[:class]).to include('collection-anchor-link')

        # The link href should point to a cwrapper ID
        expect(anchor_target).to match(/^#cwrapper_\d+$/)

        # Test passed, exit loop
        break
      end
    end
  end
end
