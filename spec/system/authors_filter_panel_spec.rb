require 'rails_helper'

describe 'Authors filter panel behavior' do
  before do
    Chewy.strategy(:atomic) do
      # Create authors with different characteristics for filtering
      create(:manifestation, author: create(:authority, gender: 'female'))
      create(:manifestation, author: create(:authority, gender: 'male'))
      create(:manifestation, author: create(:authority, gender: 'male', period: 'modern'))
    end
  end

  after do
    Chewy.massacre
  end

  context 'when no filters are applied' do
    it 'shows the intro panel and hides the filter panel' do
      visit authors_path

      # Intro should be visible, filter panel should be hidden
      expect(page).to have_css('#browse_intro', visible: :visible)
      expect(page).to have_css('#sort_filter_panel', visible: :hidden)

      # Toggle button should be in "no" state
      expect(page).to have_css('.toggle-button-no', visible: :visible)
      expect(page).to have_css('.toggle-button-yes', visible: :hidden)
    end
  end

  context 'when a filter is applied', :js do
    it 'hides the intro panel and shows the filter panel', :aggregate_failures do
      visit authors_path

      # Click the toggle to show filters
      find('#sort_filter_toggle').click

      # Wait for the filter panel to be visible using find
      find('#sort_filter_panel', visible: :visible)

      # Apply a gender filter by waiting for it to be present and checking it
      find('#gender_female', visible: :visible).click

      # Wait for AJAX to complete by checking that the filter tag appears
      expect(page).to have_css('.tag', text: 'יוצר: נקבה', wait: 5)

      # After filter is applied, the filter panel should remain visible (main fix)
      expect(find('#sort_filter_panel', visible: :all)).to be_visible
      expect(find('#browse_intro', visible: :all)).not_to be_visible

      # Toggle button should show "yes" state (at least the yes button should be visible)
      expect(find('.toggle-button-yes', visible: :all)).to be_visible
    end
  end

  context 'when filters are reset', :js do
    it 'shows the intro panel and hides the filter panel', :aggregate_failures do
      visit authors_path

      # Click the toggle to show filters
      find('#sort_filter_toggle').click

      # Wait for filter panel to be visible
      find('#sort_filter_panel', visible: :visible)

      # Apply a filter
      find('#gender_female', visible: :visible).click

      # Wait for AJAX to complete by checking that the filter tag appears
      expect(page).to have_css('.tag', text: 'יוצר: נקבה', wait: 5)

      # Verify filter is applied and panel is visible
      expect(find('#sort_filter_panel', visible: :all)).to be_visible

      # Reset filters
      find('.reset', visible: :visible).click

      # Wait for AJAX to complete by checking that the filter tag disappears
      expect(page).not_to have_css('.tag', text: 'יוצר: נקבה', wait: 5)

      # After reset, intro should be visible, filter panel should be hidden
      expect(find('#browse_intro', visible: :all)).to be_visible
      expect(find('#sort_filter_panel', visible: :all)).not_to be_visible

      # Toggle button should be in "no" state
      expect(find('.toggle-button-no', visible: :all)).to be_visible
      expect(find('.toggle-button-yes', visible: :all)).not_to be_visible
    end
  end
end
