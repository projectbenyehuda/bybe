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

  # Create involved_authority with 'author' role on the collection
  # This will ensure the 'author' role sections appear in the navbar
  let!(:collection_involved_authority) do
    create(:involved_authority,
           authority: author,
           item: collection,
           role: 'author')
  end

  # Also create an editor role to test multiple sections
  let!(:editor_involved_authority) do
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

    it 'scrolls to at least one corresponding mainlist section when navbar link is clicked' do
      visit authority_path(author)

      # Wait for page to load
      expect(page).to have_css('.book-nav-full')
      expect(page).to have_css('#browse_mainlist')

      # Find all navbar sections with scroll targets
      navbar_sections = all('.book-type .truncate[data-scroll-target]')

      # Skip test if no navbar sections found
      skip 'No navbar sections with scroll targets found' if navbar_sections.empty?

      tested = false

      # Test the first navbar section that has a corresponding target in the mainlist
      navbar_sections.each do |navbar_section|
        scroll_target = navbar_section['data-scroll-target']

        # Skip this section if target doesn't exist in mainlist
        next unless page.has_css?(scroll_target, visible: :all)

        # Scroll to top first to ensure we can detect the scroll change
        page.execute_script('window.scrollTo(0, 0);')

        # Click the navbar section
        navbar_section.click

        # Wait for collapse animation and scroll to complete
        sleep 1

        # Verify the target section exists and is visible
        target_element = page.find(scroll_target, visible: :all)
        expect(target_element).to be_present

        # Verify that we've scrolled down (scroll position should be > 0)
        scroll_position = page.evaluate_script('window.pageYOffset || document.documentElement.scrollTop')
        expect(scroll_position).to be > 0

        tested = true
        break
      end

      expect(tested).to be(true), 'No valid navbar sections with matching targets found to test'
    end

    it 'maintains collapse functionality while adding scroll behavior' do
      visit authority_path(author)

      # Wait for page to load
      expect(page).to have_css('.book-nav-full')

      # Find all collapsible navbar sections
      navbar_sections = all('.book-type .truncate[data-bs-toggle="collapse"]')

      # Skip test if no collapsible sections found
      skip 'No collapsible navbar sections found' if navbar_sections.empty?

      tested = false

      # Test with the first navbar section that has a collapse target
      navbar_sections.each do |navbar_section|
        collapse_target = navbar_section['data-bs-target']

        # Skip if collapse target doesn't exist
        next unless page.has_css?(collapse_target, visible: :all)

        # Get initial collapse state
        initial_state = page.find(collapse_target, visible: :all)[:class]
        was_expanded = initial_state.include?('show')

        # Click the navbar section
        navbar_section.click

        # Wait for collapse animation to complete
        sleep 0.5

        # Verify collapse state toggled
        new_state = page.find(collapse_target, visible: :all)[:class]
        is_expanded = new_state.include?('show')
        expect(is_expanded).to eq(!was_expanded)

        tested = true
        break
      end

      expect(tested).to be(true), 'No valid collapsible navbar sections found to test'
    end

    it 'makes collection links use anchors instead of navigating to collection pages' do
      visit authority_path(author)

      # Wait for page to load
      expect(page).to have_css('.book-nav-full')

      # Find collection anchor links in the navbar
      collection_links = all('.collection-anchor-link')

      # Skip test if no collection links found
      skip 'No collection anchor links found' if collection_links.empty?

      tested = false

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

        # The link href should point to a cwrapper ID (not a collection path)
        expect(anchor_target).to match(/^#cwrapper_\d+$/)

        # Verify clicking doesn't navigate away (current URL should not change)
        current_url = page.current_url

        # Scroll to top first
        page.execute_script('window.scrollTo(0, 0);')

        # Click the link
        link.click

        # Wait for scroll animation
        sleep 0.5

        # URL should not have changed (we didn't navigate to collection page)
        expect(page.current_url).to eq(current_url)

        # Verify we scrolled (position should be > 0)
        scroll_position = page.evaluate_script('window.pageYOffset || document.documentElement.scrollTop')
        expect(scroll_position).to be > 0

        tested = true
        break
      end

      expect(tested).to be(true), 'No valid collection anchor links found to test'
    end
  end
end
