# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Works mobile sorting', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    page.driver.browser.manage.window.resize_to(375, 812)
    visit works_path
    # Wait for page to load
    expect(page).to have_css('.by-card-v02', wait: 5)
  end

  before(:all) do
    clean_tables
    Chewy.strategy(:atomic) do
      # Create test data - just need some manifestations to exist
      @m1 = create(:manifestation, title: 'Alpha Work', impressions_count: 100)
      @m2 = create(:manifestation, title: 'Beta Work', impressions_count: 500)
      @m3 = create(:manifestation, title: 'Gamma Work', impressions_count: 200)

      ManifestationsIndex.reset!
    end
  end

  after(:all) do
    clean_tables
  end

  after do
    # Reset viewport to desktop size
    page.driver.browser.manage.window.resize_to(1920, 1080)
  end

  it 'displays mobile sorting dropdown on mobile viewport' do
    # Open the filter panel
    find('#sort_filter_toggle', wait: 5).click
    expect(page).to have_css('#filters_panel', visible: true, wait: 5)

    # Mobile sorting dropdown should be visible
    expect(page).to have_css('#sort_by_dd_mobile', visible: true, wait: 5)
  end

  it 'hides desktop sorting dropdown on mobile viewport' do
    # Desktop sorting dropdown should not be visible on mobile
    expect(page).not_to have_css('#sort_by_dd', visible: true)
  end

  it 'applies sort order immediately when dropdown changes' do
    # Open the filter panel
    find('#sort_filter_toggle', wait: 5).click
    expect(page).to have_css('#filters_panel', visible: true, wait: 5)

    # Select popularity descending
    select I18n.t(:popularity_desc), from: 'sort_by_mobile'

    # Verify the hidden field was updated
    expect(page).to have_field('sort_by', with: 'popularity_desc', type: 'hidden', wait: 5)

    # Wait for AJAX to complete (should happen automatically without clicking Apply)
    expect(page).to have_css('.mainlist', wait: 5)

    # Verify the sort is maintained in the dropdown after reopening
    find('#sort_filter_toggle', wait: 5).click
    expect(page).to have_css('#filters_panel', visible: true, wait: 5)
    expect(page).to have_select('sort_by_mobile', selected: I18n.t(:popularity_desc), wait: 5)
  end

  it 'maintains sort selection when reopening filter panel' do
    # Open the filter panel
    find('#sort_filter_toggle', wait: 5).click
    expect(page).to have_css('#filters_panel', visible: true, wait: 5)

    # Change to alphabetical descending
    select I18n.t(:alefbet_desc), from: 'sort_by_mobile'

    # Verify the hidden field was updated
    expect(page).to have_field('sort_by', with: 'alphabetical_desc', type: 'hidden', wait: 5)

    # Wait for AJAX to complete (should happen automatically)
    expect(page).to have_css('.mainlist', wait: 5)

    # Open filter panel again
    find('#sort_filter_toggle', wait: 5).click
    expect(page).to have_css('#filters_panel', visible: true, wait: 5)

    # The previously selected sort should still be selected
    expect(page).to have_select('sort_by_mobile', selected: I18n.t(:alefbet_desc), wait: 5)
  end
end
