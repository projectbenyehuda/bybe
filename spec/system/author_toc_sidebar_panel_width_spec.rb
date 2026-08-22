# frozen_string_literal: true

require 'rails_helper'

# Regression for by-ccq: the Lexicon merge (#1578) renamed the sidebar column's
# spacer div from .side-menu-area-left (display:none on desktop) to
# .author-side-menu-area (a 230px flex basis meant for the TOC column, which is
# the only one the sticky nav rail floats over). That reserved 230px inside the
# col-lg-4 sidebar for nothing, squeezing the panels down to 216px in a 476px
# column at a 1600px viewport.
describe 'Author TOC sidebar panel width', :js do
  let(:author) { create(:authority, name: 'Test Author Sidebar Width') }
  let(:sidebar_col) { '.author-page-content > .row > .col-12.col-lg-4' }
  let(:sidebar_card) { "#{sidebar_col} .by-card-v02" }

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?

    Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Test Work Sidebar Width', status: :published, author: author)
    end
    visit authority_path(author)
  end

  after do
    Chewy.massacre
  end

  # Width of the sidebar column and of the first panel in it.
  def sidebar_metrics
    expect(page).to have_css(sidebar_card)
    page.evaluate_script(<<~JS)
      [document.querySelector('#{sidebar_col}').getBoundingClientRect().width,
       document.querySelector('#{sidebar_card}').getBoundingClientRect().width]
    JS
  end

  it 'gives the side panels nearly the whole sidebar column on a wide desktop' do
    page.driver.browser.manage.window.resize_to(1600, 900)
    col_width, card_width = sidebar_metrics

    # The panels sit in a .col inside the column, so only the grid gutters
    # (~30px) should separate the two widths -- not a 230px rail spacer.
    expect(card_width).to be > (col_width - 60),
                          "Side panel is #{card_width.round}px inside a #{col_width.round}px " \
                          'sidebar column -- the spacer is eating its width'
  end

  it 'keeps the side panels clear of the nav rail below 992px' do
    page.driver.browser.manage.window.resize_to(768, 900)
    expect(page).to have_css(sidebar_card)

    # Below 992px the sidebar stacks under the TOC column, so the sticky rail
    # floats over it too and its spacer must stay on the line. RTL page: the
    # rail is on the right, so the panels must end to its left.
    rail_right, panel_right = page.evaluate_script(<<~JS)
      [document.querySelector('.author-side-nav-col').getBoundingClientRect().right,
       document.querySelector('#{sidebar_card}').getBoundingClientRect().right]
    JS

    expect(panel_right).to be <= rail_right,
                           "Side panel right edge (#{panel_right.round}px) overlaps " \
                           "the nav rail (right edge #{rail_right.round}px)"
  end
end
