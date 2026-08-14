# frozen_string_literal: true

require 'rails_helper'

# The Authority TOC action bar carries different actions per view (bead r81):
# the grouped (volumes) view gets Collapse all / Expand all, while the flat texts
# list gets the list/summaries display switch. The summaries view fetches each
# work's excerpt lazily from ManifestationController#snippets.
describe 'Author TOC action bar', :js do
  # Lazy `let` (not `let!`) so the WebDriver skip in the before hook can
  # short-circuit without running the DB + Chewy setup when Chrome is unavailable.
  let(:author) { create(:authority, name: 'Bar Author') }
  let(:volume) { create(:collection, title: 'A Volume', collection_type: :volume) }

  let(:poem) do
    Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Alpha Poem', status: :published, author: author,
                             markdown: 'The opening line of the Alpha poem.')
    end
  end
  let(:story) do
    Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Beta Story', status: :published, author: author,
                             markdown: 'The opening line of the Beta story.')
    end
  end

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?

    create(:collection_item, collection: volume, item: poem)
    create(:collection_item, collection: volume, item: story)
    create(:involved_authority, authority: author, item: volume, role: 'editor')
  end

  after { Chewy.massacre }

  def choose_sort(value)
    find("#sort_by option[value='#{value}']").select_option
  end

  it 'swaps the collapse/expand buttons for the display switch in the flat list, and back' do
    visit authority_path(author)
    expect(page).to have_css('#browse_mainlist .volume-collapse-toggle')

    # Grouped view: volume actions only.
    expect(page).to have_css('#max_collapse', visible: :visible)
    expect(page).to have_css('#expand-all', visible: :visible)
    expect(page).to have_css('#tocmode_list', visible: :hidden)
    expect(page).to have_css('#tocmode_snippets', visible: :hidden)

    choose_sort('title')

    # Flat list: display switch only, starting on the plain list.
    expect(page).to have_css('#tocmode_list.active', visible: :visible)
    expect(page).to have_css('#tocmode_snippets', visible: :visible)
    expect(page).to have_no_css('#tocmode_snippets.active', visible: :visible)
    expect(page).to have_no_css('#max_collapse')
    expect(page).to have_no_css('#expand-all')

    choose_sort('colls')

    expect(page).to have_css('#max_collapse', visible: :visible)
    expect(page).to have_css('#expand-all', visible: :visible)
    expect(page).to have_css('#tocmode_list', visible: :hidden)
  end

  it 'shows each work\'s excerpt in the summaries view and drops it again in the list view' do
    visit authority_path(author)
    choose_sort('title')
    expect(page).to have_css('#sorted_card .manifestation-node', minimum: 2)
    expect(page).to have_no_css('.toc-snippet')

    find('#tocmode_snippets').click

    expect(page).to have_css('.toc-snippet', count: 2)
    expect(page).to have_content('The opening line of the Alpha poem.')
    expect(page).to have_content('The opening line of the Beta story.')
    expect(page).to have_css('#tocmode_snippets.active')

    find('#tocmode_list').click

    expect(page).to have_no_css('.toc-snippet', visible: :all)
    expect(page).to have_no_content('The opening line of the Alpha poem.')
    expect(page).to have_css('#tocmode_list.active')
  end

  it 'keeps the summaries view across a re-sort within the flat list' do
    visit authority_path(author)
    choose_sort('title')
    find('#tocmode_snippets').click
    expect(page).to have_css('.toc-snippet', count: 2)

    choose_sort('popularity_desc')

    # The nodes are only reordered, so their excerpts travel with them.
    expect(page).to have_css('#tocmode_snippets.active')
    expect(page).to have_css('.toc-snippet', count: 2)
  end

  it 'falls back to the list view when leaving the flat list' do
    visit authority_path(author)
    choose_sort('title')
    find('#tocmode_snippets').click
    expect(page).to have_css('.toc-snippet', count: 2)

    choose_sort('colls')
    expect(page).to have_no_css('.toc-snippet', visible: :all)

    choose_sort('title')

    expect(page).to have_css('#tocmode_list.active', visible: :visible)
    expect(page).to have_no_css('.toc-snippet', visible: :all)
  end
end
