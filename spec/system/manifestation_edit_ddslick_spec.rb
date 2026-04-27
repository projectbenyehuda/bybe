# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Manifestation edit ddslick dropdown', :js, type: :system do
  # NOTE: ddslick is vendored at app/assets/javascripts/jquery.ddslick.min.js — no CDN dependency.
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  let(:user) { create(:user, :edit_catalog) }
  let!(:manifestation) do
    create(:manifestation, status: :published).tap do |m|
      # Attach some test images to test the ddslick dropdown
      # Use binread + StringIO to avoid leaking file descriptors
      test_image_path = Rails.root.join('spec/fixtures/files/test_image.jpg')
      image_data = File.binread(test_image_path)
      m.images.attach(
        io: StringIO.new(image_data),
        filename: 'test_image_1.jpg',
        content_type: 'image/jpeg'
      )
      m.images.attach(
        io: StringIO.new(image_data),
        filename: 'test_image_2.jpg',
        content_type: 'image/jpeg'
      )
      # Set known dimensions so data-width/data-height are rendered and can be asserted.
      # 'analyzed' must be in the metadata JSON (not a separate column) to prevent the helper
      # from calling blob.analyze, which would overwrite our dimensions with the fixture's real 1x1 size.
      m.images.each do |img|
        img.blob.update!(metadata: img.blob.metadata.merge('analyzed' => true, 'width' => 800, 'height' => 600))
      end
    end
  end

  def login_as_editor
    # System specs require stubbing at the controller level
    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    # rubocop:enable RSpec/AnyInstance
    user
  end

  context 'when visiting edit page multiple times' do
    before do
      login_as_editor
    end

    it 'does not grow the dd-select container on repeated visits' do
      3.times do
        visit manifestation_edit_path(manifestation)
        expect(page).to have_css('.dd-selected-text', wait: 5)
      end
      # Only one dd-container should exist — re-initialization would create duplicates
      expect(page.evaluate_script("$('.dd-container').length")).to eq(1)
    end
  end

  context 'when opening the dropdown multiple times' do
    before do
      login_as_editor
    end

    it 'does not grow the dd-select container on repeated opens' do
      visit manifestation_edit_path(manifestation)
      expect(page).to have_css('.dd-selected-text', wait: 5)

      # Disable jQuery animations so ddslick's internal slideUp(50) is instant,
      # preventing the open/close toggle from mis-firing mid-animation.
      page.execute_script('$.fx.off = true')

      3.times do
        find('.dd-select').click
        expect(page).to have_css('.dd-options', visible: true, wait: 5)
        page.execute_script("$('#images').ddslick('close')")
        expect(page).to have_css('.dd-options', visible: false, wait: 5)
      end

      # Only one dd-container should exist — re-initialization would create duplicates
      expect(page.evaluate_script("$('.dd-container').length")).to eq(1)
    end
  end

  context 'when ddslick is properly initialized' do
    before do
      login_as_editor
    end

    it 'only initializes once' do
      visit manifestation_edit_path(manifestation)
      expect(page).to have_css('.dd-select', wait: 5)

      # Check that dd-container only exists once
      container_count = page.evaluate_script("$('.dd-container').length")
      expect(container_count).to eq(1)

      # Check that the original select is properly replaced
      expect(page).to have_css('#images', visible: false)
    end
  end

  context 'when inserting images' do
    before do
      login_as_editor
    end

    it 'auto-selects the next image after inserting an image' do
      visit manifestation_edit_path(manifestation)
      expect(page).to have_css('.dd-select', wait: 5)

      # Wait for initial selection to be set (ddslick initializes asynchronously)
      expect(page).to have_css('.dd-selected-text', text: 'test_image_1.jpg', wait: 5)

      # Get the initial selected index (should be 0)
      initial_index = page.evaluate_script("$('#images').data('ddslick').selectedIndex")
      expect(initial_index).to eq(0)

      # Click the add image button
      find('#add_image').click

      # Wait for the selection to change by checking the selected text
      expect(page).to have_css('.dd-selected-text', text: 'test_image_2.jpg', wait: 5)

      # Verify the next image is now selected
      new_index = page.evaluate_script("$('#images').data('ddslick').selectedIndex")
      expect(new_index).to eq(1)

      # Verify the selected filename changed
      new_filename = page.evaluate_script("$('#images').data('ddslick').selectedData.text")
      expect(new_filename).to eq('test_image_2.jpg')

      # Verify the image was inserted in the markdown textarea
      markdown_content = page.evaluate_script("$('#markdown').val()")
      expect(markdown_content).to include('<img')
      expect(markdown_content).to include('alt="test_image_1.jpg"')
      expect(markdown_content).to include('width="800"')
      expect(markdown_content).to include('height="600"')
    end

    it 'does not advance beyond the last image' do
      visit manifestation_edit_path(manifestation)
      expect(page).to have_css('.dd-select', wait: 5)

      # Select the last image (index 1, since we have 2 images)
      page.execute_script("$('#images').ddslick('select', {index: 1})")

      # Wait for selection to update by checking the selected text
      expect(page).to have_css('.dd-selected-text', text: 'test_image_2.jpg', wait: 5)

      # Verify we're on the last image
      current_index = page.evaluate_script("$('#images').data('ddslick').selectedIndex")
      expect(current_index).to eq(1)

      # Click the add image button
      find('#add_image').click

      # Verify we're still on the last image by checking the text hasn't changed
      # (it should remain test_image_2.jpg)
      expect(page).to have_css('.dd-selected-text', text: 'test_image_2.jpg', wait: 5)

      # Verify we're still on the last image (didn't wrap around or error)
      final_index = page.evaluate_script("$('#images').data('ddslick').selectedIndex")
      expect(final_index).to eq(1)

      # Verify the image was still inserted
      markdown_content = page.evaluate_script("$('#markdown').val()")
      expect(markdown_content).to include('<img')
      expect(markdown_content).to include('alt="test_image_2.jpg"')
      expect(markdown_content).to include('width="800"')
      expect(markdown_content).to include('height="600"')
    end
  end
end
