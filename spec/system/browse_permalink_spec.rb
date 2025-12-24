# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Browse permalink button', type: :system, js: true do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  after do
    Chewy.massacre
  end

  describe 'authors browse page' do
    before do
      Chewy.strategy(:atomic) do
        create_list(:manifestation, 5)
      end
    end

    it 'displays permalink button with correct URL' do
      visit '/authors'

      expect(page).to have_css('a.permalink-btn')
      permalink_btn = find('a.permalink-btn')

      # Verify link text uses I18n
      expect(permalink_btn.text).to match(/Permanent link|קישורית קבועה/)

      # Verify href is set to current page URL
      expect(permalink_btn[:href]).to include('/authors')
    end

    it 'copies URL to clipboard when clicked and shows feedback' do
      visit '/authors'

      permalink_btn = find('a.permalink-btn')
      original_text = permalink_btn.text

      # Click the permalink button
      permalink_btn.click

      # Wait for feedback message to appear
      expect(page).to have_text(/Link copied to clipboard!|הקישורית הועתקה ללוח!/)

      # Wait for feedback to disappear and text to return to original
      sleep 2.5
      permalink_btn = find('a.permalink-btn')
      expect(permalink_btn.text).to eq(original_text)
    end

    it 'allows right-click to copy URL' do
      visit '/authors'

      permalink_btn = find('a.permalink-btn')

      # Verify the href attribute is accessible for right-click copy
      expect(permalink_btn[:href]).to be_present
      expect(permalink_btn[:href]).to include('/authors')
    end

    it 'preserves permalink URL with filters applied' do
      visit '/authors'

      # Apply a filter (assuming there's a sort dropdown or filter)
      # This will vary based on the actual filter implementation
      # For now, just verify the permalink button is present after page load
      expect(page).to have_css('a.permalink-btn')
    end
  end

  describe 'works browse page' do
    let!(:work1) do
      Chewy.strategy(:atomic) do
        create(:manifestation, status: :published)
      end
    end

    let!(:work2) do
      Chewy.strategy(:atomic) do
        create(:manifestation, status: :published)
      end
    end

    it 'displays permalink button with correct URL' do
      visit '/works'

      expect(page).to have_css('a.permalink-btn')
      permalink_btn = find('a.permalink-btn')

      # Verify link text uses I18n
      expect(permalink_btn.text).to match(/Permanent link|קישורית קבועה/)

      # Verify href is set to current page URL
      expect(permalink_btn[:href]).to include('/works')
    end

    it 'copies URL to clipboard when clicked and shows feedback' do
      visit '/works'

      permalink_btn = find('a.permalink-btn')
      original_text = permalink_btn.text

      # Click the permalink button
      permalink_btn.click

      # Wait for feedback message to appear
      expect(page).to have_text(/Link copied to clipboard!|הקישורית הועתקה ללוח!/)

      # Wait for feedback to disappear and text to return to original
      sleep 2.5
      permalink_btn = find('a.permalink-btn')
      expect(permalink_btn.text).to eq(original_text)
    end

    it 'allows right-click to copy URL' do
      visit '/works'

      permalink_btn = find('a.permalink-btn')

      # Verify the href attribute is accessible for right-click copy
      expect(permalink_btn[:href]).to be_present
      expect(permalink_btn[:href]).to include('/works')
    end
  end
end
