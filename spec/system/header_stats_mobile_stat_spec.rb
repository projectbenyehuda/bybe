# frozen_string_literal: true

require 'rails_helper'

# The header statistics box shows four stats on a desktop, but only has room for
# one below 992px, where BY_styles_Max991.css hides all but the surviving child.
# That child used to be picked by source order (`:first-child`), so reordering
# the box quietly swapped the single mobile stat from the works count to the
# volumes count. The stat to keep is now marked with .mobile-stat.
RSpec.describe 'Header statistics box', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  # Any page in the main layout carries the header; this one is cheap to render.
  def visit_page_at(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
    visit '/pby_volumes'
    expect(page).to have_css('.statistics-box-v02', visible: :visible, wait: 5)
  end

  it 'shows only the works count on a phone-sized viewport' do
    visit_page_at(390, 844)

    expect(page).to have_css('.statistics-box-v02 .statistics-v02.mobile-stat', visible: :visible)
    expect(page).to have_css('.statistics-box-v02 .statistics-v02:not(.mobile-stat)',
                             visible: :hidden, count: 3)

    # The one stat left standing is the works count, not the volumes count.
    expect(page).to have_css('.statistics-box-v02 .statistics-v02.mobile-stat',
                             text: I18n.t(:works), visible: :visible)
    expect(page).to have_css(".statistics-box-v02 .statistics-v02.mobile-stat a[href='#{all_works_path}']",
                             visible: :visible)
  end

  it 'still shows every stat on a desktop-sized viewport' do
    visit_page_at(1280, 900)

    expect(page).to have_css('.statistics-box-v02 .statistics-v02', visible: :visible, count: 4)
  end
end
