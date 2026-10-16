# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sitewide search box clear button', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    visit '/pby_volumes'
  end

  it 'is hidden while the box is empty' do
    expect(page).to have_field('q', with: '')
    expect(page).to have_css('#q-clear', visible: :hidden)
  end

  it 'appears once text is typed and clears the box when clicked' do
    fill_in 'q', with: 'ביאליק'
    expect(page).to have_css('#q-clear', visible: :visible)

    find_by_id('q-clear').click

    expect(page).to have_field('q', with: '')
    expect(page).to have_css('#q-clear', visible: :hidden)
    expect(page).to have_current_path('/pby_volumes')
  end

  it 'sits near the left edge of the search box' do
    fill_in 'q', with: 'ביאליק'
    expect(page).to have_css('#q-clear', visible: :visible)

    offset = page.evaluate_script(<<~JS)
      document.getElementById('q-clear').getBoundingClientRect().left -
        document.querySelector('.top-search-box-v02').getBoundingClientRect().left
    JS
    expect(offset).to be_between(0, 50)
  end

  it 'keeps the search icon inside the search box' do
    fill_in 'q', with: 'ביאליק'
    expect(page).to have_css('#q-clear', visible: :visible)

    overflow = page.evaluate_script(<<~JS)
      (function () {
        var box = document.querySelector('.top-search-box-v02').getBoundingClientRect();
        var icon = document.querySelector('.top-search-v02 .search-icon-v02').getBoundingClientRect();
        return Math.max(box.top - icon.top, icon.bottom - box.bottom, 0);
      })()
    JS
    expect(overflow).to be <= 2
  end
end
