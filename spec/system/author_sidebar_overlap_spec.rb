# frozen_string_literal: true

require 'rails_helper'

describe 'Author page sidebar overlap regression', :js do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  after do
    Chewy.massacre
  end

  # Reproduces the bug at 992-1279px where the flex-wrap caused the content col
  # to take full row width, overlapping the fixed sidebar.
  it 'does not overlap sidebar with content at 1054px viewport width' do
    author = create(:authority, name: 'Test Author')
    Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Test Work', status: :published, author: author)
    end

    page.driver.browser.manage.window.resize_to(1054, 768)
    visit authority_path(author)
    expect(page).to have_css('.book-nav-full')

    # The main content right edge must not reach the sidebar left edge.
    # Sidebar (.author-side-nav-col) is at x≈(viewport-215) from left.
    # Content (.col:not(.author-side-menu-area)) must end before that.
    content_col_selector =
      '.author-page-content .col-12.col-lg-8 > .row > .col:not(.author-side-menu-area)'
    expect(page).to have_css('.author-side-nav-col')
    expect(page).to have_css(content_col_selector)

    sidebar_left = page.evaluate_script(
      "document.querySelector('.author-side-nav-col').getBoundingClientRect().left"
    )
    content_right = page.evaluate_script(
      "document.querySelector('#{content_col_selector}').getBoundingClientRect().right"
    )

    expect(content_right).to be <= sidebar_left,
                             "Content right edge (#{content_right}px) overlaps " \
                             "sidebar left edge (#{sidebar_left}px)"
  end

  it 'does not overlap sidebar with content at 992px viewport width' do
    author = create(:authority, name: 'Test Author 992')
    Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Test Work 992', status: :published, author: author)
    end

    page.driver.browser.manage.window.resize_to(992, 768)
    visit authority_path(author)
    expect(page).to have_css('.book-nav-full')

    content_col_selector =
      '.author-page-content .col-12.col-lg-8 > .row > .col:not(.author-side-menu-area)'
    expect(page).to have_css('.author-side-nav-col')
    expect(page).to have_css(content_col_selector)

    sidebar_left = page.evaluate_script(
      "document.querySelector('.author-side-nav-col').getBoundingClientRect().left"
    )
    content_right = page.evaluate_script(
      "document.querySelector('#{content_col_selector}').getBoundingClientRect().right"
    )

    expect(content_right).to be <= sidebar_left,
                             "Content right edge (#{content_right}px) overlaps " \
                             "sidebar left edge (#{sidebar_left}px)"
  end
end
