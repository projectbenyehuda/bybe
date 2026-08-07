# frozen_string_literal: true

require 'rails_helper'

# Regression test for the homepage author carousels leaving a large blank area above the
# "works in the project" (most-read) card on mobile: #welcome-authors had an unconditional
# min-height of 720px, which only matches the natural content height on wide viewports.
RSpec.describe 'Homepage authors card height', :js, type: :system do
  before(:all) do
    clean_tables
    Chewy.strategy(:atomic) do
      create_list(:authority, 3, :with_image)
      create(:manifestation, title: 'Alpha Work', impressions_count: 100)
      ManifestationsIndex.reset!
    end
  end

  after(:all) do
    clean_tables
  end

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  after do
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  # Vertical distance in pixels between the last visible content of the authors card (the
  # "to all authors" link) and the top of the works card. Measuring the card's own bottom would
  # not catch the bug, since the blank space is *inside* the card.
  def gap_below_authors_content
    page.evaluate_script(<<~JS)
      (function() {
        var link = document.querySelector('#welcome-authors .link-to-all-v02');
        var works = document.querySelector('#works-in-project');
        return works.getBoundingClientRect().top - link.getBoundingClientRect().bottom;
      })();
    JS
  end

  it 'does not leave a large blank area under the carousels on mobile' do
    page.driver.browser.manage.window.resize_to(375, 812)
    visit root_path
    expect(page).to have_css('#works-in-project', wait: 5)

    expect(gap_below_authors_content).to be < 60
  end

  it 'keeps the CLS-reducing min-height on wide viewports' do
    page.driver.browser.manage.window.resize_to(1400, 1400)
    visit root_path
    expect(page).to have_css('#works-in-project', wait: 5)

    expect(page.evaluate_script("getComputedStyle(document.querySelector('#welcome-authors')).minHeight"))
      .to eq('720px')
  end
end
