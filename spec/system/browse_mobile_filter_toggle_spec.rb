# frozen_string_literal: true

require 'rails_helper'

# On a mobile viewport the browse lists used to render the sort/filter panel
# above the list, so the first screenful held no list items at all. The panel
# must now be collapsed behind the single #mobile_filter_btn toggle.
describe 'Browse lists mobile filter toggle', :js do
  let!(:authority) { create(:authority, name: 'Mobile Toggle Author') }
  let!(:manifestation) { create(:manifestation, title: 'Mobile Toggle Work', author: authority) }
  let!(:collection) do
    create(:collection, title: 'Mobile Toggle Volume', collection_type: :volume, sort_title: 'mobile toggle volume')
  end

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?

    Chewy.strategy(:atomic) do
      ManifestationsIndex.reset!
      AuthoritiesIndex.reset!
      CollectionsIndex.reset!
    end
    page.driver.browser.manage.window.resize_to(375, 812)
  end

  after do
    page.driver.browser.manage.window.resize_to(1400, 900)
    Chewy.massacre
  end

  # The list card and the toggle button must both be within the first screenful,
  # and the filter panel must not be pushing them down.
  def expect_list_first
    expect(page).to have_css('#thelist', visible: :visible, wait: 5)
    expect(page).to have_css('#sort_filter_panel', visible: :hidden)
    expect(page).to have_css('#mobile_filter_btn', visible: :visible)

    viewport_height = page.evaluate_script('window.innerHeight')
    list_top = page.evaluate_script("document.getElementById('thelist').getBoundingClientRect().top")
    expect(list_top).to be < viewport_height
  end

  { 'works' => '/works', 'authors' => '/authors', 'collections' => '/collections' }.each do |name, path|
    context "when browsing /#{name}" do
      it 'shows the list first, with the filters collapsed behind the toggle' do
        visit path

        expect_list_first
      end

      it 'reveals and re-hides the filter panel via the toggle button' do
        visit path
        expect(page).to have_css('#mobile_filter_btn', visible: :visible, wait: 5)

        find('#mobile_filter_btn').click

        expect(page).to have_css('#sort_filter_panel', visible: :visible, wait: 5)
        expect(find('#mobile_filter_btn')['aria-expanded']).to eq('true')
        expect(find('#mobile_filter_btn')).to have_text(I18n.t(:hide_sort_and_filter))

        find('#mobile_filter_btn').click

        expect(page).to have_css('#sort_filter_panel', visible: :hidden, wait: 5)
        expect(find('#mobile_filter_btn')['aria-expanded']).to eq('false')
        expect(find('#mobile_filter_btn')).to have_text(I18n.t(:sort_and_filter))
      end
    end
  end

  context 'when on a desktop viewport' do
    before do
      page.driver.browser.manage.window.resize_to(1400, 900)
    end

    it 'keeps the filter panel open and hides the mobile toggle' do
      visit '/works'

      expect(page).to have_css('#sort_filter_panel', visible: :visible, wait: 5)
      expect(page).to have_css('#mobile_filter_btn', visible: :hidden)
    end
  end
end
