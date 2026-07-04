# frozen_string_literal: true

require 'rails_helper'

# Flat-list filters pane for the Authority TOC (bead ln5): changing the sort order
# away from the default swaps the navbar for a filters pane and filters the flat
# manifestation list in-browser.
describe 'Author TOC flat-list filters', :js do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  let!(:author) { create(:authority, name: 'Filter Author') }
  let!(:volume) { create(:collection, title: 'A Volume', collection_type: :volume) }

  let!(:poem) do
    Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Alpha Poem', status: :published, author: author,
                             genre: 'poetry', orig_lang: 'he', language: 'he',
                             publication_date: '2010-01-01')
    end
  end
  let!(:story) do
    Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Beta Story', status: :published, author: author,
                             genre: 'prose', orig_lang: 'ru', language: 'he',
                             publication_date: '2020-01-01')
    end
  end

  before do
    create(:collection_item, collection: volume, item: poem)
    create(:collection_item, collection: volume, item: story)
    create(:involved_authority, authority: author, item: volume, role: 'editor')
  end

  after { Chewy.massacre }

  def choose_sort(value)
    find("#sort_by option[value='#{value}']").select_option
  end

  it 'swaps the navbar for the filters pane when sorting away from the default, and back' do
    visit authority_path(author)
    expect(page).to have_css('#browse_mainlist')

    # default (colls): navbar visible, filters hidden
    expect(page).to have_css('.book-nav-full', visible: :visible)
    expect(page).to have_css('#toc_filters_pane', visible: :hidden)

    choose_sort('title')
    expect(page).to have_css('#toc_filters_pane', visible: :visible)
    expect(page).to have_css('.book-nav-full', visible: :hidden)
    expect(page).to have_css('#sorted_card .manifestation-node', minimum: 2)

    # back to default: navbar restored, filters hidden
    choose_sort('colls')
    expect(page).to have_css('#toc_filters_pane', visible: :hidden)
    expect(page).to have_css('.book-nav-full', visible: :visible)
  end

  it 'activates alphabetical filtering mode via the desktop sort/filter toggle' do
    visit authority_path(author)
    expect(page).to have_css('#browse_mainlist')

    # off state: filters hidden, toggle showing the "no" knob, default sort
    expect(page).to have_css('#toc_filters_pane', visible: :hidden)
    expect(page).to have_css('.author-page-top-sort-desktop .toggle-button-yes', visible: :hidden)

    find('#toc-filter-toggle').click
    expect(page).to have_css('#toc_filters_pane', visible: :visible)
    expect(page).to have_css('#sorted_card .manifestation-node', minimum: 2)
    expect(page).to have_css('.author-page-top-sort-desktop .toggle-button-yes', visible: :visible)
    expect(page).to have_css('.author-page-top-sort-desktop .toggle-button-no', visible: :hidden)
    expect(find('#sort_by').value).to eq('title')

    # clicking again returns to the default grouped view
    find('#toc-filter-toggle').click
    expect(page).to have_css('#toc_filters_pane', visible: :hidden)
    expect(page).to have_css('.author-page-top-sort-desktop .toggle-button-yes', visible: :hidden)
    expect(find('#sort_by').value).to eq('colls')
  end

  it 'filters the flat list by free-text name (debounced)' do
    visit authority_path(author)
    choose_sort('title')
    expect(page).to have_css('#sorted_card .manifestation-node', minimum: 2)

    fill_in 'toc-filter-name', with: 'Alpha'
    within '#sorted_card' do
      expect(page).to have_content('Alpha Poem')
      expect(page).to have_no_content('Beta Story')
    end
  end

  it 'filters by genre and updates the faceted counts' do
    visit authority_path(author)
    choose_sort('title')

    # initial faceted counts computed from the nodes
    expect(page).to have_css(".toc-facet-count[data-value='poetry']", text: '(1)')
    expect(page).to have_css(".toc-facet-count[data-value='prose']", text: '(1)')

    check 'toc-filter-genre-poetry'
    within '#sorted_card' do
      expect(page).to have_content('Alpha Poem')
      expect(page).to have_no_content('Beta Story')
    end
  end

  it 'filters by source language (translated)' do
    visit authority_path(author)
    choose_sort('title')

    check 'toc-filter-translated'
    within '#sorted_card' do
      expect(page).to have_content('Beta Story')
      expect(page).to have_no_content('Alpha Poem')
    end
  end

  it 'filters by upload-year date range and renders a histogram' do
    visit authority_path(author)
    choose_sort('title')

    btn = find(".toc-date-type[data-datefield='upload-year']")
    scroll_to(btn)
    btn.click
    expect(page).to have_css('#toc-date-histogram .toc-hist-bar', minimum: 1)

    from = find('#toc-date-from')
    scroll_to(from)
    from.set('2015')
    from.send_keys(:tab) # blur to fire the change handler
    within '#sorted_card' do
      expect(page).to have_content('Beta Story')
      expect(page).to have_no_content('Alpha Poem')
    end
  end

  it 'clears all filters via the reset link' do
    visit authority_path(author)
    choose_sort('title')

    check 'toc-filter-genre-poetry'
    within('#sorted_card') { expect(page).to have_no_content('Beta Story') }

    find('#toc-filter-reset').click
    within '#sorted_card' do
      expect(page).to have_content('Alpha Poem')
      expect(page).to have_content('Beta Story')
    end
    expect(page).to have_no_css('.toc-filter-genre:checked')
  end
end
