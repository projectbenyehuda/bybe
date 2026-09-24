# frozen_string_literal: true

require 'rails_helper'

# Regression test for GH #1702. At phone widths the scrolled header hides the
# donation buttons and was meant to show a shekel icon instead
# (.donation-icon-only, styled in BY_styles_General.css / BY_styles_Max479.css),
# but that element was never in the markup, so the donation link vanished.
RSpec.describe 'Mobile top-bar donation icon', :js, :narrow_viewport, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    resize_window(400, 800)
  end

  it 'replaces the donation button with an icon next to the search icon once scrolled' do
    visit '/pby_volumes'

    expect(page).to have_css('#donev_mobile_top_banner .donation-btn-v02', visible: :visible)
    expect(page).to have_css('#donev_mobile_top_banner_icon', visible: :hidden)

    # Guarantee there is room to scroll past the 100px threshold, whatever the page content.
    page.execute_script("document.body.style.minHeight = '3000px'; window.scrollTo(0, 500);")
    expect(page).to have_css('header.scrolled', wait: 5)

    expect(page).to have_css('#donev_mobile_top_banner_icon[href="/page/donate"]', visible: :visible, text: 'z')
    expect(page).to have_css('.topMobileBtns-v02 .donation-btn-v02', visible: :visible, count: 0)

    gap = page.evaluate_script(<<~JS)
      (function () {
        var icon = document.getElementById('donev_mobile_top_banner_icon').getBoundingClientRect();
        var search = document.getElementById('mobile_search').getBoundingClientRect();
        return icon.left - search.right;
      })()
    JS
    # RTL: the icon sits immediately to the right of the search icon.
    expect(gap).to be_between(0, 12)
  end
end
