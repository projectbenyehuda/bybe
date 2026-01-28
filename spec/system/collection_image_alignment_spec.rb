# frozen_string_literal: true

require 'rails_helper'

describe 'Collection image alignment' do
  # Use a properly-sized test image (300x200 solid blue PNG) as data URI
  # This is large enough to meaningfully test alignment and centering
  let(:test_image_data_uri) do
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAASwAAADICAYAAABS39xVAAAACXBIWXMAAA7EAAAOxAGVKw4bAAABpElEQVR4nO3BMQEAAADCoPVPbQwfoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAOBrAx5RAAGFXPj9AAAAAElFTkSuQmCC'
  end

  let(:html_with_image) do
    <<~HTML
      <h2>Test Collection Content</h2>
      <p>Here is some text before the image.</p>
      <img src="#{test_image_data_uri}" alt="Test Image" width="300" height="200">
      <p>Here is some text after the image.</p>
    HTML
  end

  # Create test data - use before block to ensure proper ordering and persistence
  let!(:author) { create(:authority) }
  let!(:collection) { create(:collection, authors: [author], collection_type: 'volume') }

  before do
    # Create collection item with markdown content containing an image
    create(:collection_item,
           collection: collection,
           markdown: html_with_image,
           seqno: 1)

    # Verify the item was created
    collection.reload
    expect(collection.collection_items.count).to eq(1)

    # Index for search if needed
    Chewy.strategy(:atomic) { CollectionsIndex.reset! }
  end

  after do
    Chewy.massacre
  end

  describe 'image centering in collection show view', js: true do
    it 'applies center-alignment styles to images' do
      visit collection_path(collection)

      # Wait for the main content area to be present
      expect(page).to have_css('.by-card-content-v02.textcard#actualtext', wait: 10)

      # Wait for image to be present in the content
      expect(page).to have_css('.by-card-content-v02.textcard#actualtext img', wait: 5)

      # Find the image element
      within('.by-card-content-v02.textcard#actualtext') do
        img = find('img')

        # Verify max-width constraint (should be 100% to prevent overflow)
        max_width = page.evaluate_script("getComputedStyle(arguments[0]).maxWidth", img.native)
        expect(max_width).to eq('100%')

        # Verify display: block (required for margin auto to work)
        display = page.evaluate_script("getComputedStyle(arguments[0]).display", img.native)
        expect(display).to eq('block')

        # Verify horizontal centering via equal left/right margins
        margin_left = page.evaluate_script("getComputedStyle(arguments[0]).marginLeft", img.native)
        margin_right = page.evaluate_script("getComputedStyle(arguments[0]).marginRight", img.native)
        expect(margin_left).to eq(margin_right), "Image should be centered with equal margins (left: #{margin_left}, right: #{margin_right})"
      end
    end
  end
end
