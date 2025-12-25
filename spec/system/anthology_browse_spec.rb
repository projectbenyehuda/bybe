# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Anthology browse page', type: :system, js: true do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  let(:user) { create(:user) }
  let!(:public_anthology) do
    create(:anthology, title: 'Public Anthology Test', access: :pub, user: user)
  end
  let!(:private_anthology) do
    create(:anthology, title: 'Private Anthology Test', access: :priv, user: user)
  end

  describe 'browsing public anthologies' do
    it 'displays only public anthologies' do
      visit '/anthologies/browse'

      expect(page).to have_content('Public Anthology Test')
      expect(page).not_to have_content('Private Anthology Test')
    end

    it 'displays welcome message and intro' do
      visit '/anthologies/browse'

      expect(page).to have_css('.headline-1-v02')
    end

    it 'displays filter panel when filters are shown' do
      visit '/anthologies/browse'

      # The filter panel exists but may be hidden
      expect(page).to have_css('#anthologies_filters', visible: :all)
    end

    it 'displays sort options' do
      visit '/anthologies/browse'

      expect(page).to have_css('#sort_by_select')
    end
  end

  describe 'filtering' do
    let!(:anthology_with_text) do
      anthology = create(:anthology, title: 'Poetry Collection', access: :pub, user: user)
      manifestation = create(:manifestation, title: 'Sample Poem', status: :published)
      create(:anthology_text, anthology: anthology, manifestation: manifestation)
      anthology
    end

    # These tests verify that filtering functionality exists
    # Note: The filter inputs are in collapsed panels which require complex UI interactions
    # so we test them via URL parameters which simulate the filter form submission
    it 'filters by anthology title via URL parameters' do
      visit anthologies_browse_path(title_filter: 'Poetry')

      expect(page).to have_content('Poetry Collection')
      expect(page).not_to have_content('Public Anthology Test')
    end

    it 'filter form exists with expected inputs' do
      visit '/anthologies/browse'

      # Verify filter inputs exist (even if hidden)
      expect(page).to have_field('title_filter', visible: :all)
      expect(page).to have_field('owner_filter', visible: :all)
      expect(page).to have_field('author_filter', visible: :all)
      expect(page).to have_field('manifestation_filter', visible: :all)
    end
  end

  describe 'sorting' do
    let!(:anthology_a) { create(:anthology, title: 'AAA Anthology', access: :pub, user: user) }
    let!(:anthology_z) { create(:anthology, title: 'ZZZ Anthology', access: :pub, user: user) }

    it 'sorts alphabetically ascending by default' do
      visit '/anthologies/browse'

      anthology_titles = all('.mainlist li a').map(&:text)
      expect(anthology_titles.first).to eq('AAA Anthology')
    end

    it 'can sort alphabetically descending' do
      visit '/anthologies/browse'

      # Use the Hebrew or English option text
      select_option = find('#sort_by_select option[value="alphabetical_desc"]')
      select_option.select_option

      # Wait for the list to update with the sorted results
      expect(page).to have_selector('.mainlist li a', text: 'ZZZ Anthology')
      anthology_titles = all('.mainlist li a').map(&:text)
      expect(anthology_titles.first).to eq('ZZZ Anthology')
    end
  end

  describe 'pagination' do
    before do
      # Reduced from 60 to 51 - just need to trigger pagination at 50+ threshold
      51.times do |i|
        create(:anthology, title: "Anthology #{i.to_s.rjust(2, '0')}", access: :pub, user: user)
      end
    end

    it 'displays pagination controls when there are more than 50 anthologies' do
      visit '/anthologies/browse'

      expect(page).to have_css('.pagination-controls')
      # Check for Hebrew or English page indicators
      expect(page).to have_content(/עמוד.*מתוך|Page.*of/)
    end

    it 'can navigate to next page' do
      visit '/anthologies/browse'

      # Find and click the next page link
      next_link = find('.pagination-link', match: :first)
      next_link.click

      # Wait for page 2 content to appear (Hebrew or English)
      expect(page).to have_content(/עמוד 2|Page 2/)
    end
  end

  describe 'permalink button' do
    it 'displays permalink button with correct URL' do
      visit '/anthologies/browse'

      expect(page).to have_css('a.permalink-btn')
      permalink_btn = find('a.permalink-btn')

      # Verify link text uses I18n
      expect(permalink_btn.text).to match(/Permanent link|קישורית קבועה/)

      # Verify href is set to current page URL
      expect(permalink_btn[:href]).to include('/anthologies/browse')
    end

    it 'copies URL to clipboard when clicked and shows feedback' do
      visit '/anthologies/browse'

      permalink_btn = find('a.permalink-btn')
      original_text = permalink_btn.text

      # Click the permalink button
      permalink_btn.click

      # Wait for feedback message to appear
      expect(page).to have_text(/Link copied to clipboard!|הקישורית הועתקה ללוח!/)

      # Wait for feedback to disappear and text to return to original
      # Using Capybara's built-in waiting instead of sleep for better performance
      expect(page).to have_selector('a.permalink-btn', text: original_text, wait: 3)
    end
  end
end
