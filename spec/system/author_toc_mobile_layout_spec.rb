# frozen_string_literal: true

require 'rails_helper'

# Regression tests for the mobile author TOC layout.
#
# The collapse/expand/sort bar is an unwrappable flexbox, so on a phone the two
# buttons plus the sort dropdown did not fit on one line and spilled out of the
# page. Mobile browsers react to a document wider than the screen by widening
# the layout viewport, which stretched the fixed #header (width: 100%) past the
# screen edge and slid the sticky nav column off its 50px gutter and on top of
# the author metadata.
#
# Desktop browsers do not widen the layout viewport, so these specs cannot
# reproduce the displaced header directly -- they guard its cause, the
# horizontal overflow, plus the sidebar column's own gutter.
RSpec.describe 'Author TOC mobile layout', :js, type: :system do
  let!(:author) { create(:authority, name: 'Test Author') }

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Test Work', status: :published, author: author)
    end
    page.driver.browser.manage.window.resize_to(375, 667)
  end

  after { Chewy.massacre }

  # Loads the author page and waits for the sticky elements this spec measures.
  def visit_toc_at_mobile_width
    visit authority_path(author)
    expect(page).to have_css('.author-side-nav-col', wait: 5)
    expect(page).to have_css('.sticky-fold', wait: 5)
    expect(page.evaluate_script('document.documentElement.clientWidth')).to be < 992
  end

  it 'does not overflow the page horizontally' do
    visit_toc_at_mobile_width

    overflow = page.evaluate_script(
      'document.documentElement.scrollWidth - document.documentElement.clientWidth'
    )

    expect(overflow).to be <= 1, "page overflows its viewport by #{overflow}px"
  end

  it 'keeps the sort/collapse bar within its card' do
    visit_toc_at_mobile_width

    overflow = page.evaluate_script(
      "(function(e){ return e.scrollWidth - e.clientWidth; })(document.querySelector('.sticky-fold'))"
    )

    expect(overflow).to be <= 0, "sort/collapse bar overflows its card by #{overflow}px"
  end

  # Below 992px the col-lg-4 sidebar column stacks full-width under the main
  # column, so it needs its own spacer to stay clear of the sticky nav column.
  it 'keeps the sidebar column clear of the sticky nav column' do
    visit_toc_at_mobile_width

    sidebar_row = '.author-page-content .col-12.col-lg-4 > .row'
    # This column's spacer is .side-menu-area-left (the main column's is
    # .author-side-menu-area) -- exclude both so we measure the content col.
    sidebar_col = "#{sidebar_row} > .col:not(.author-side-menu-area):not(.side-menu-area-left)"
    expect(page).to have_css(sidebar_col, wait: 5)

    # The spacer and the content col must stay on one line, or the content col
    # takes the full row width and slides under the nav column.
    flex_wrap = page.evaluate_script(
      "window.getComputedStyle(document.querySelector('#{sidebar_row}')).flexWrap"
    )
    expect(flex_wrap).to eq('nowrap')

    nav_left = page.evaluate_script(
      "document.querySelector('.author-side-nav-col').getBoundingClientRect().left"
    )
    sidebar_right = page.evaluate_script(
      "document.querySelector('#{sidebar_col}').getBoundingClientRect().right"
    )

    expect(sidebar_right).to be <= nav_left,
                             "sidebar column right edge (#{sidebar_right}px) runs under " \
                             "the nav column left edge (#{nav_left}px)"
  end
end
