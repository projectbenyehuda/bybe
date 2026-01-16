# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Author navbar mobile expansion', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  let!(:author) do
    create(:authority, name: 'Test Author')
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

  describe 'mobile navbar expansion' do
    before do
      # Set mobile viewport (less than 991px)
      page.driver.browser.manage.window.resize_to(375, 667)
    end

    it 'expands thin navbar to show full navbar when expand button is clicked' do
      visit authority_path(author)

      # Wait for page to load
      expect(page).to have_css('.book-nav-thin')

      # Initially, thin navbar should be visible and full navbar should be hidden
      expect(page).to have_css('.book-nav-thin', visible: :visible)
      expect(page).to have_css('.book-nav-full', visible: :hidden)
      expect(page).not_to have_css('.mobile-navbar-backdrop.active', visible: :visible)

      # Click the expand button
      find('.horizontal-collapse-expand').click

      # After clicking, full navbar should be visible with mobile-expanded class
      # and backdrop should be active
      expect(page).to have_css('.book-nav-full.mobile-expanded', visible: :visible)
      expect(page).to have_css('.book-nav-thin', visible: :hidden)
      expect(page).to have_css('.mobile-navbar-backdrop.active', visible: :visible)

      # Verify the navbar is wider (300px)
      navbar_width = page.evaluate_script("$('.book-nav-full.mobile-expanded').width()")
      expect(navbar_width).to eq(300)
    end

    it 'collapses full navbar back to thin when a nav link is clicked' do
      visit authority_path(author)

      # Wait for page to load
      expect(page).to have_css('.book-nav-thin')

      # Expand the navbar
      find('.horizontal-collapse-expand').click
      expect(page).to have_css('.book-nav-full.mobile-expanded', visible: :visible)
      expect(page).to have_css('.mobile-navbar-backdrop.active', visible: :visible)

      # Click a nav link in the expanded navbar
      within('.book-nav-full.mobile-expanded') do
        first('.book-type[data-scroll-target], .truncate[data-scroll-target], .nav-link').click
      end

      # After clicking, navbar should collapse back to thin and backdrop should be hidden
      expect(page).to have_css('.book-nav-thin', visible: :visible)
      expect(page).not_to have_css('.book-nav-full.mobile-expanded', visible: :visible)
      expect(page).not_to have_css('.mobile-navbar-backdrop.active', visible: :visible)
    end

    it 'allows multiple expand-collapse cycles via nav links' do
      visit authority_path(author)

      # Wait for page to load
      expect(page).to have_css('.book-nav-thin')

      # First cycle: Expand and collapse via nav link
      find('.horizontal-collapse-expand').click
      expect(page).to have_css('.book-nav-full.mobile-expanded', visible: :visible)

      within('.book-nav-full.mobile-expanded') do
        first('.book-type[data-scroll-target], .truncate[data-scroll-target], .nav-link').click
      end
      expect(page).to have_css('.book-nav-thin', visible: :visible)

      # Second cycle: Verify it works multiple times
      find('.horizontal-collapse-expand').click
      expect(page).to have_css('.book-nav-full.mobile-expanded', visible: :visible)

      within('.book-nav-full.mobile-expanded') do
        first('.book-type[data-scroll-target], .truncate[data-scroll-target], .nav-link').click
      end
      expect(page).to have_css('.book-nav-thin', visible: :visible)
    end

    it 'collapses navbar when clicking on backdrop' do
      visit authority_path(author)

      # Wait for page to load
      expect(page).to have_css('.book-nav-thin')

      # Expand the navbar
      find('.horizontal-collapse-expand').click
      expect(page).to have_css('.book-nav-full.mobile-expanded', visible: :visible)
      expect(page).to have_css('.mobile-navbar-backdrop.active', visible: :visible)

      # Click the backdrop in an area not covered by the navbar (right side of screen)
      # The navbar is 300px wide on the left, so click at x=350 (right side)
      page.driver.browser.action.move_to_location(350, 300).click.perform

      # Navbar should collapse
      expect(page).to have_css('.book-nav-thin', visible: :visible)
      expect(page).not_to have_css('.book-nav-full.mobile-expanded', visible: :visible)
      expect(page).not_to have_css('.mobile-navbar-backdrop.active', visible: :visible)
    end

    it 'allows scrolling within the expanded navbar' do
      visit authority_path(author)

      # Wait for page to load
      expect(page).to have_css('.book-nav-thin')

      # Expand the navbar
      find('.horizontal-collapse-expand').click
      expect(page).to have_css('.book-nav-full.mobile-expanded', visible: :visible)

      # Verify navbar has overflow-y: auto
      overflow = page.evaluate_script("$('.book-nav-full.mobile-expanded').css('overflow-y')")
      expect(overflow).to eq('auto')

      # Verify max-height is set (should be viewport height minus top position)
      max_height = page.evaluate_script("$('.book-nav-full.mobile-expanded').css('max-height')")
      expect(max_height).to match(/\d+px/)
    end
  end
end
