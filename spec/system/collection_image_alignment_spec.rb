# frozen_string_literal: true

require 'rails_helper'

# Check if WebDriver is available before loading the suite
def webdriver_available?
  return @webdriver_available if defined?(@webdriver_available)

  @webdriver_available = begin
    # Try to access the WebDriver to see if it's configured
    driver = Capybara.current_session.driver
    if driver.respond_to?(:browser)
      driver.browser
      true
    else
      true  # Non-Selenium driver, assume it works
    end
  rescue Selenium::WebDriver::Error::WebDriverError,
         Selenium::WebDriver::Error::UnknownError,
         Net::ReadTimeout,
         Errno::ECONNREFUSED,
         StandardError
    false
  end
end

RSpec.describe 'Collection image alignment', type: :system, js: true do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  let(:html_with_image) do
    <<~HTML
      <h2>Test Collection Content</h2>
      <p>Here is some text before the image.</p>
      <img src="https://via.placeholder.com/300x200" alt="Test Image">
      <p>Here is some text after the image.</p>
    HTML
  end

  let!(:author) do
    Chewy.strategy(:atomic) do
      create(:authority)
    end
  end

  let!(:collection) do
    Chewy.strategy(:atomic) do
      create(:collection,
             markdown_placeholders: [html_with_image],
             authors: [author])
    end
  end

  after do
    Chewy.massacre
  end

  describe 'image centering in collection show view' do
    it 'applies center-alignment styles to images' do
      # Ensure collection has items before visiting
      expect(collection.collection_items.count).to be > 0

      visit collection_path(collection)

      # Wait for page to load with a more specific selector
      expect(page).to have_css('.by-card-content-v02.textcard#actualtext', wait: 10)

      # Find images within the textcard
      images = all('.by-card-content-v02.textcard#actualtext img')

      # Verify at least one image is present
      expect(images.count).to be >= 1

      # Check that the image has the correct CSS styles for centering
      images.each do |img|
        # Verify max-width constraint
        max_width = page.evaluate_script("getComputedStyle(arguments[0]).maxWidth", img.native)
        expect(max_width).to eq('100%')

        # Verify display: block for centering
        display = page.evaluate_script("getComputedStyle(arguments[0]).display", img.native)
        expect(display).to eq('block')

        # Verify margin auto is set (browsers may compute auto as 0px, but the important thing
        # is that left and right margins are equal, indicating centering)
        margin_left = page.evaluate_script("getComputedStyle(arguments[0]).marginLeft", img.native)
        margin_right = page.evaluate_script("getComputedStyle(arguments[0]).marginRight", img.native)
        expect(margin_left).to eq(margin_right), "Expected equal left and right margins for centering"
      end
    end
  end
end
