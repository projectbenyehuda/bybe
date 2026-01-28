# frozen_string_literal: true

require 'rails_helper'

describe 'Author navbar mobile expansion', js: true do
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

    it 'preserves navbar state when clicking collapsible triggers' do
      visit authority_path(author)

      # Wait for page to load
      expect(page).to have_css('.book-nav-thin')

      # Expand the navbar
      find('.horizontal-collapse-expand').click
      expect(page).to have_css('.book-nav-full.mobile-expanded', visible: :visible)
      expect(page).to have_css('.mobile-navbar-backdrop.active', visible: :visible)

      # Click a collapsible trigger (has data-bs-toggle="collapse")
      collapsible_trigger = first('.book-nav-full.mobile-expanded .truncate[data-bs-toggle="collapse"]')

      if collapsible_trigger
        collapsible_trigger.click

        # Navbar should still be expanded (not collapsed)
        expect(page).to have_css('.book-nav-full.mobile-expanded', visible: :visible)
        expect(page).to have_css('.mobile-navbar-backdrop.active', visible: :visible)
        expect(page).not_to have_css('.book-nav-thin', visible: :visible)
      end
    end

    it 'allows multiple expand-collapse cycles via backdrop' do
      visit authority_path(author)

      # Wait for page to load
      expect(page).to have_css('.book-nav-thin')

      # First cycle: Expand and collapse via backdrop
      find('.horizontal-collapse-expand').click
      expect(page).to have_css('.book-nav-full.mobile-expanded', visible: :visible)

      page.execute_script("$('.mobile-navbar-backdrop.active').trigger('click')")
      expect(page).not_to have_css('.book-nav-full.mobile-expanded', visible: :visible)
      expect(page).to have_css('.book-nav-thin', visible: :visible)

      # Second cycle: Verify it works multiple times
      find('.horizontal-collapse-expand').click
      expect(page).to have_css('.book-nav-full.mobile-expanded', visible: :visible)

      page.execute_script("$('.mobile-navbar-backdrop.active').trigger('click')")
      expect(page).not_to have_css('.book-nav-full.mobile-expanded', visible: :visible)
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

      # Click the backdrop using JavaScript (more reliable than coordinates)
      page.execute_script("$('.mobile-navbar-backdrop.active').trigger('click')")

      # Wait for collapse to complete
      expect(page).not_to have_css('.book-nav-full.mobile-expanded', visible: :visible)

      # Navbar should be back to thin
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

    it 'allows collapsible sections to expand/collapse without closing navbar' do
      visit authority_path(author)

      # Wait for page to load
      expect(page).to have_css('.book-nav-thin')

      # Expand the navbar
      find('.horizontal-collapse-expand').click
      expect(page).to have_css('.book-nav-full.mobile-expanded', visible: :visible)

      # Find a collapsible trigger (has data-bs-toggle="collapse")
      collapsible_trigger = first('.book-nav-full.mobile-expanded .truncate[data-bs-toggle="collapse"]')

      if collapsible_trigger
        # Click the collapsible trigger
        collapsible_trigger.click

        # Mobile navbar should still be expanded
        expect(page).to have_css('.book-nav-full.mobile-expanded', visible: :visible)
        expect(page).to have_css('.mobile-navbar-backdrop.active', visible: :visible)

        # The collapse section should toggle (we don't check if it's shown or hidden,
        # just that the navbar is still expanded)
        expect(page).to have_css('.book-nav-full.mobile-expanded')
      end
    end
  end
end
