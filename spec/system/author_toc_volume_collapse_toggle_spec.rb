# frozen_string_literal: true

require 'rails_helper'

# Covers the per-volume collapse toggle added to the Authority TOC: each
# volume-type collection with children gets a chevron toggle at the end of its
# title line that collapses/expands only that volume's children list.
describe 'Author TOC per-volume collapse toggle', :js do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  let!(:author) { create(:authority, name: 'Test Author') }

  let!(:volume) do
    create(:collection, title: 'Test Volume', collection_type: :volume)
  end

  let!(:work_in_volume) do
    Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Work in Volume', status: :published, author: author)
    end
  end

  let!(:collection_item) do
    create(:collection_item, collection: volume, item: work_in_volume)
  end

  let!(:involved_authority) do
    create(:involved_authority, authority: author, item: volume, role: 'editor')
  end

  after { Chewy.massacre }

  it 'shows a collapse toggle on the volume and toggles only that volume' do
    visit authority_path(author)

    expect(page).to have_css('#browse_mainlist')
    toggle = find('#browse_mainlist .volume-collapse-toggle', match: :first)

    card = toggle.find(:xpath, "./ancestor::li[contains(@class, 'by-card-v02')][1]")
    # This volume's own children list lives directly under its cwrapper.
    cwrapper = toggle.find(:xpath, "./ancestor::div[contains(@class, 'cwrapper')][1]")

    # Initially expanded: children visible, toggle not collapsed
    expect(card['aria-expanded']).to eq('true')
    expect(cwrapper).to have_css('ul.toclist', visible: :visible)
    expect(toggle[:class]).not_to include('collapsed')
    expect(toggle['aria-expanded']).to eq('true')

    # Collapse this volume (Capybara waits for the slide animation to finish)
    toggle.click
    expect(cwrapper).to have_css('ul.toclist', visible: :hidden)
    expect(toggle[:class]).to include('collapsed')
    expect(card['aria-expanded']).to eq('false')
    expect(toggle['aria-expanded']).to eq('false')

    # Expand it again
    toggle.click
    expect(cwrapper).to have_css('ul.toclist', visible: :visible)
    expect(toggle[:class]).not_to include('collapsed')
    expect(card['aria-expanded']).to eq('true')
    expect(toggle['aria-expanded']).to eq('true')
  end

  it 'drops the toggle for a single-work volume pruned into a single link' do
    # prune_collections() collapses a volume into a single link when it holds exactly one
    # manifestation whose title matches the collection title. Such a volume has nothing left
    # to collapse, so it must NOT carry a per-volume toggle.
    solo_title = 'Solo Volume'
    solo_volume = create(:collection, title: solo_title, collection_type: :volume)
    solo_work = Chewy.strategy(:atomic) do
      create(:manifestation, title: solo_title, status: :published, author: author)
    end
    create(:collection_item, collection: solo_volume, item: solo_work)
    create(:involved_authority, authority: author, item: solo_volume, role: 'editor')

    visit authority_path(author)
    expect(page).to have_css('#browse_mainlist')

    # NOTE: a volume can render in both the collection-level and work-level sections, so its
    # cwrapper id is not unique; assert via CSS existence (matches every copy) rather than find.

    # The mismatched-title volume from the shared fixtures keeps its toggle...
    expect(page).to have_css("#cwrapper_#{volume.id} .volume-collapse-toggle")

    # ...but every copy of the pruned single-work volume must have had its toggle removed
    # (have_no_css waits for prune_collections to run on page load)...
    expect(page).to have_no_css("#cwrapper_#{solo_volume.id} .volume-collapse-toggle")

    # ...and none of its cards may still advertise an expandable state.
    all("#cwrapper_#{solo_volume.id}").each do |cw|
      card = cw.find(:xpath, "./ancestor::li[contains(@class, 'by-card-v02')][1]")
      expect(card['aria-expanded']).to be_nil
    end
  end

  it 'keeps individual toggles in sync with the collapse-all / expand-all buttons' do
    visit authority_path(author)

    expect(page).to have_css('#browse_mainlist .volume-collapse-toggle')

    find('#max_collapse').click
    expect(page).to have_css('#browse_mainlist .volume-collapse-toggle.collapsed')
    # every toggle must be collapsed, not just some (class and its own aria-expanded)
    expect(page).to have_no_css('#browse_mainlist .volume-collapse-toggle:not(.collapsed)')
    expect(page).to have_no_css('#browse_mainlist .volume-collapse-toggle[aria-expanded="true"]')

    find('#expand-all').click
    expect(page).to have_css('#browse_mainlist .volume-collapse-toggle:not(.collapsed)')
    # every toggle must be expanded, not just some (class and its own aria-expanded)
    expect(page).to have_no_css('#browse_mainlist .volume-collapse-toggle.collapsed')
    expect(page).to have_no_css('#browse_mainlist .volume-collapse-toggle[aria-expanded="false"]')
  end
end
