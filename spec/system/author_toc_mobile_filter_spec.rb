# frozen_string_literal: true

require 'rails_helper'

# Mobile filtering for the authority TOC (/authors/:id). Below 992px the desktop
# sort/filter toggle is hidden and the filters pane lives in a 34px nav rail, so
# filtering used to be unreachable there (the mobile button was an inert
# placeholder). It is now the same toggle + "apply" row the browse lists use,
# and the pane is revealed as a sheet over the page.
describe 'Author TOC mobile filtering', :js do
  # Lazy `let` (not `let!`) so the WebDriver skip in the before hook can
  # short-circuit without running the DB + Chewy setup when Chrome is unavailable.
  let(:author) { create(:authority, name: 'Mobile Filter Author') }
  let(:volume) { create(:collection, title: 'A Volume', collection_type: :volume) }

  let(:poem) do
    Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Alpha Poem', status: :published, author: author,
                             genre: 'poetry', orig_lang: 'he', language: 'he')
    end
  end
  let(:story) do
    Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Beta Story', status: :published, author: author,
                             genre: 'prose', orig_lang: 'he', language: 'he')
    end
  end

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?

    create(:collection_item, collection: volume, item: poem)
    create(:collection_item, collection: volume, item: story)
    create(:involved_authority, authority: author, item: volume, role: 'editor')
    page.driver.browser.manage.window.resize_to(375, 812)
  end

  after do
    page.driver.browser.manage.window.resize_to(1400, 900)
    Chewy.massacre
  end

  # True when the element is wholly inside the viewport right now.
  def fully_on_screen?(selector)
    page.evaluate_script(<<~JS)
      (function() {
        var rect = document.getElementById('#{selector}').getBoundingClientRect();
        return rect.top >= 0 && rect.bottom <= window.innerHeight && rect.height > 0;
      })()
    JS
  end

  it 'starts with the works list showing and the filters collapsed behind the toggle' do
    visit authority_path(author)
    expect(page).to have_css('#browse_mainlist', wait: 5)

    expect(page).to have_css('#mobile_filter_btn', visible: :visible)
    expect(page).to have_css('#toc_filters_pane', visible: :hidden)
    # The desktop toggle has no place here.
    expect(page).to have_css('.author-page-top-sort-desktop', visible: :hidden)
  end

  it 'reveals the filters pane and puts the list into filter mode, then re-hides it' do
    visit authority_path(author)
    expect(page).to have_css('#browse_mainlist', wait: 5)

    find('#mobile_filter_btn').click

    expect(page).to have_css('#toc_filters_pane', visible: :visible, wait: 5)
    # Same logic as the desktop toggle: filtering operates on the flat list.
    expect(page).to have_css('#sorted_card .manifestation-node', minimum: 2)
    expect(find('#sort_by').value).to eq('title')
    expect(find('#mobile_filter_btn')['aria-expanded']).to eq('true')
    expect(find('#mobile_filter_btn')).to have_text(I18n.t(:hide_sort_and_filter))

    find('#mobile_filter_btn').click

    expect(page).to have_css('#toc_filters_pane', visible: :hidden, wait: 5)
    expect(find('#mobile_filter_btn')['aria-expanded']).to eq('false')
    expect(find('#mobile_filter_btn')).to have_text(I18n.t(:sort_and_filter))
  end

  it 'offers the same filter content as the desktop pane, and filters the list' do
    visit authority_path(author)
    expect(page).to have_css('#browse_mainlist', wait: 5)

    find('#mobile_filter_btn').click
    expect(page).to have_css('#toc_filters_pane', visible: :visible, wait: 5)

    # every section of the desktop pane is here
    expect(page).to have_css('#toc-filter-name', visible: :visible)
    expect(page).to have_css('#toc-filter-genre-poetry', visible: :all)
    expect(page).to have_css('#toc-filter-lang-he', visible: :all)
    expect(page).to have_css('#toc-filter-curatorial', visible: :all)
    expect(page).to have_css('#toc-date-histogram', visible: :visible)

    check 'toc-filter-genre-poetry'
    within '#sorted_card' do
      expect(page).to have_content('Alpha Poem')
      expect(page).to have_no_content('Beta Story')
    end
  end

  it 'keeps both buttons on screen while the pane is scrolled' do
    visit authority_path(author)
    expect(page).to have_css('#browse_mainlist', wait: 5)

    # "Apply" is hidden until there is something to apply.
    expect(page).to have_css('#apply_mobile_filters', visible: :hidden)

    find('#mobile_filter_btn').click
    expect(page).to have_css('#apply_mobile_filters', visible: :visible, wait: 5)

    page.execute_script('window.scrollTo(0, 600)')
    expect(page.evaluate_script('window.scrollY')).to be > 0

    expect(fully_on_screen?('mobile_filter_btn')).to be true
    expect(fully_on_screen?('apply_mobile_filters')).to be true
  end

  it 'collapses the pane over the filtered results when apply is clicked' do
    visit authority_path(author)
    expect(page).to have_css('#browse_mainlist', wait: 5)

    find('#mobile_filter_btn').click
    expect(page).to have_css('#apply_mobile_filters', visible: :visible, wait: 5)
    check 'toc-filter-genre-poetry'

    find('#apply_mobile_filters').click

    expect(page).to have_css('#toc_filters_pane', visible: :hidden, wait: 5)
    expect(find('#mobile_filter_btn')['aria-expanded']).to eq('false')
    # The filtering survives the collapse -- as on the browse lists.
    within '#sorted_card' do
      expect(page).to have_content('Alpha Poem')
      expect(page).to have_no_content('Beta Story')
    end
  end

  # The sheet covers the sticky sort bar while it is open, so the route back to
  # the grouped view is: collapse the sheet, then re-sort. The filters pane and
  # the in-page navbar swap back, exactly as they do on desktop.
  it 'restores the grouped view and the in-page navbar via the sort dropdown' do
    visit authority_path(author)
    expect(page).to have_css('#browse_mainlist', wait: 5)

    find('#mobile_filter_btn').click
    expect(page).to have_css('#toc_filters_pane', visible: :visible, wait: 5)
    expect(page).to have_css('#sorted_card')

    find('#apply_mobile_filters').click
    expect(page).to have_css('#toc_filters_pane', visible: :hidden, wait: 5)

    find("#sort_by option[value='colls']").select_option

    expect(page).to have_no_css('#sorted_card')
    expect(page).to have_css('#toc_filters_pane', visible: :hidden)
    expect(find('#mobile_filter_btn')['aria-expanded']).to eq('false')
    expect(page).to have_css('.book-nav-thin', visible: :visible)
  end

  context 'when on a desktop viewport' do
    before { page.driver.browser.manage.window.resize_to(1400, 900) }

    it 'hides the mobile toggle row and keeps the desktop toggle' do
      visit authority_path(author)
      expect(page).to have_css('#browse_mainlist', wait: 5)

      expect(page).to have_css('.toc-mobile-filter-toggle', visible: :hidden)
      expect(page).to have_css('#mobile_filter_btn', visible: :hidden)
      expect(page).to have_css('#apply_mobile_filters', visible: :hidden)
      expect(page).to have_css('.author-page-top-sort-desktop', visible: :visible)
    end
  end
end
