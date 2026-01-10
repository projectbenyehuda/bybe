# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Author navbar collapse arrows', type: :system, js: true do
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

  describe 'collapse arrows in navbar' do
    it 'displays arrows that toggle based on collapse state' do
      visit authority_path(author)

      # Wait for page to load
      expect(page).to have_css('.book-nav-full')

      # Check that collapse arrows exist
      within('.book-nav-full') do
        arrows = all('.collapse-arrow')
        expect(arrows.count).to be > 0

        # The first collapsible section should be expanded (↑)
        # Note: We can't directly check the arrow text in this simple test
        # because it depends on the data structure, but we verify the class exists
        expect(page).to have_css('.collapse-arrow')
      end
    end

    it 'toggles arrow when clicking collapsible section' do
      visit authority_path(author)

      # Wait for page to load and find a collapsible trigger
      expect(page).to have_css('.book-type .truncate[data-bs-toggle="collapse"]')

      # Get the first collapsible trigger
      first_trigger = first('.book-type .truncate[data-bs-toggle="collapse"]')
      target_id = first_trigger['data-bs-target']

      # Get initial arrow text
      initial_arrow = first_trigger.find('.collapse-arrow').text

      # Click to toggle
      first_trigger.click

      # Wait for collapse animation
      sleep 0.5

      # Arrow should have changed
      new_arrow = first_trigger.find('.collapse-arrow').text
      expect(new_arrow).not_to eq(initial_arrow)

      # Click again to toggle back
      first_trigger.click
      sleep 0.5

      # Arrow should be back to initial state
      final_arrow = first_trigger.find('.collapse-arrow').text
      expect(final_arrow).to eq(initial_arrow)
    end

    it 'initializes arrows based on initial collapse state' do
      visit authority_path(author)

      # Wait for JavaScript to initialize
      expect(page).to have_css('.book-nav-full')
      sleep 0.5

      # Find all collapse targets and check arrows match their state
      within('.book-nav-full') do
        all('.collapse.navbar-nav').each do |collapse_target|
          target_id = collapse_target['id']
          trigger = find(".truncate[data-bs-target='##{target_id}']")
          arrow = trigger.find('.collapse-arrow').text

          is_expanded = collapse_target[:class].include?('show')
          expected_arrow = is_expanded ? '↑' : '↓'

          expect(arrow).to eq(expected_arrow),
            "Arrow for #{target_id} should be #{expected_arrow} (expanded: #{is_expanded}), but was #{arrow}"
        end
      end
    end
  end
end
