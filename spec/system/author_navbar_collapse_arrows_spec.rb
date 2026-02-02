# frozen_string_literal: true

require 'rails_helper'

describe 'Author navbar collapse arrows', :js do
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

      # Get initial arrow text
      initial_arrow = first_trigger.find('.collapse-arrow').text

      # Determine expected arrow after click
      expected_arrow = initial_arrow == '↑' ? '↓' : '↑'

      # Click to toggle
      first_trigger.click

      # Capybara waits for arrow to change
      expect(first_trigger.find('.collapse-arrow')).to have_text(expected_arrow)

      # Verify arrow actually changed
      new_arrow = first_trigger.find('.collapse-arrow').text
      expect(new_arrow).not_to eq(initial_arrow)
      expect(new_arrow).to eq(expected_arrow)
    end

    it 'initializes arrows based on initial collapse state' do
      visit authority_path(author)

      # Wait for JavaScript to initialize
      expect(page).to have_css('.book-nav-full')
      expect(page).to have_css('.collapse-arrow')

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
