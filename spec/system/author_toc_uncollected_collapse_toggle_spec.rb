# frozen_string_literal: true

require 'rails_helper'

# The uncollected-works card in the Authority TOC must be individually collapsible, just like the
# volume cards above it: it carries the same chevron toggle, which collapses only its own list.
describe 'Author TOC uncollected-works collapse toggle', :js do
  # Lazy `let` (not `let!`) so the WebDriver skip in the before hook can
  # short-circuit without doing any DB/Chewy work when Chrome is unavailable.
  let(:author) { create(:authority, name: 'Uncollected Toggle Author') }
  let(:volume) { create(:collection, title: 'A Volume', collection_type: :volume) }

  let(:uncollected_sel) { '#browse_mainlist .cwrapper.uncollected' }
  let(:uncollected_toggle_sel) { "#{uncollected_sel} .volume-collapse-toggle" }
  let(:volume_sel) { "#browse_mainlist .cwrapper[data-collection-id='#{volume.id}']" }

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?

    Chewy.strategy(:atomic) do
      # Title differs from the volume title, so prune_collections() leaves the volume's toggle in place.
      work_in_volume = create(:manifestation, title: 'Work In Volume', status: :published, author: author,
                                              genre: 'poetry', orig_lang: 'he', language: 'he')
      create(:collection_item, collection: volume, item: work_in_volume)
      # A standalone work by the author, in no collection -> lands in "uncollected".
      create(:manifestation, title: 'Solo Uncollected Work', status: :published, author: author,
                             genre: 'poetry', orig_lang: 'he', language: 'he')
    end
    create(:involved_authority, authority: author, item: volume, role: 'editor')
    RefreshUncollectedWorksCollection.call(author)
  end

  after { Chewy.massacre }

  it 'collapses and re-expands only the uncollected works list' do
    visit authority_path(author)
    expect(page).to have_css(uncollected_toggle_sel)

    toggle = find(uncollected_toggle_sel, match: :first)
    cwrapper = toggle.find(:xpath, "./ancestor::div[contains(@class, 'cwrapper')][1]")
    card = toggle.find(:xpath, "./ancestor::li[contains(@class, 'by-card-v02')][1]")

    # Initially expanded
    expect(card['aria-expanded']).to eq('true')
    expect(cwrapper).to have_css('ul.toclist', visible: :visible)
    expect(toggle[:class]).not_to include('collapsed')
    expect(toggle['aria-expanded']).to eq('true')

    # Collapse: the uncollected list hides, the volume's list is untouched
    toggle.click
    expect(cwrapper).to have_css('ul.toclist', visible: :hidden)
    expect(toggle[:class]).to include('collapsed')
    expect(card['aria-expanded']).to eq('false')
    expect(toggle['aria-expanded']).to eq('false')
    expect(page).to have_css("#{volume_sel} > ul.toclist", visible: :visible)

    # Expand again
    toggle.click
    expect(cwrapper).to have_css('ul.toclist', visible: :visible)
    expect(toggle[:class]).not_to include('collapsed')
    expect(card['aria-expanded']).to eq('true')
    expect(toggle['aria-expanded']).to eq('true')
  end

  it 'keeps the uncollected toggle in sync with the collapse-all / expand-all buttons' do
    visit authority_path(author)
    expect(page).to have_css(uncollected_toggle_sel)

    find('#max_collapse').click
    expect(page).to have_css("#{uncollected_toggle_sel}.collapsed")
    expect(page).to have_css("#{uncollected_sel} > ul.toclist", visible: :hidden)
    expect(page).to have_no_css("#{uncollected_toggle_sel}[aria-expanded='true']")

    find('#expand-all').click
    expect(page).to have_css("#{uncollected_toggle_sel}:not(.collapsed)")
    expect(page).to have_css("#{uncollected_sel} > ul.toclist", visible: :visible)
    expect(page).to have_no_css("#{uncollected_toggle_sel}[aria-expanded='false']")
  end
end
