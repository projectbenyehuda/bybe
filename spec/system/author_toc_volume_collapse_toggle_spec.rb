# frozen_string_literal: true

require 'rails_helper'

# Covers the per-collection collapse toggle in the Authority TOC: every
# collection card with children — whatever its collection_type — gets a chevron
# toggle at the end of its title line that collapses/expands only that
# collection's own children list.
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

  it 'gives non-volume collection types their own toggle' do
    # Toggles are not limited to volumes: any collection card rendering a
    # children list gets one (here a periodical).
    periodical_work = Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Work in Periodical', status: :published, author: author)
    end
    periodical = create(:collection, title: 'Test Periodical', collection_type: :periodical)
    create(:collection_item, collection: periodical, item: periodical_work)
    create(:involved_authority, authority: author, item: periodical, role: 'editor')

    visit authority_path(author)
    expect(page).to have_css('#browse_mainlist')

    toggle = find("#cwrapper_#{periodical.id} .volume-collapse-toggle", match: :first)
    cwrapper = toggle.find(:xpath, "./ancestor::div[contains(@class, 'cwrapper')][1]")

    toggle.click
    expect(cwrapper).to have_css('ul.toclist', visible: :hidden)
    expect(toggle[:class]).to include('collapsed')

    toggle.click
    expect(cwrapper).to have_css('ul.toclist', visible: :visible)
    expect(toggle[:class]).not_to include('collapsed')
  end

  it 'cascades expansion into nested sub-collections when re-expanding a volume after collapse-all' do
    # Expanding a volume reveals its whole subtree, so a nested collection left
    # collapsed by collapse-all is never stranded out of reach.
    # Give the nested work a different author so it renders only inside the
    # series (avoids a duplicate copy in this author's work-level section).
    other_author = create(:authority, name: 'Other Author')
    inner_work = Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Nested Series Work', status: :published, author: other_author)
    end
    series = create(:collection, title: 'Inner Series', collection_type: :series)
    create(:collection_item, collection: series, item: inner_work)

    outer_volume = create(:collection, title: 'Outer Volume', collection_type: :volume)
    create(:collection_item, collection: outer_volume, item: series)
    create(:involved_authority, authority: author, item: outer_volume, role: 'editor')

    visit authority_path(author)
    expect(page).to have_css('#browse_mainlist')

    # Both the nested series and its parent volume carry their own toggle.
    expect(page).to have_css("#cwrapper_#{series.id} .volume-collapse-toggle")
    expect(page).to have_css("#cwrapper_#{outer_volume.id} .volume-collapse-toggle")

    # Initially the deeply nested work is visible.
    expect(page).to have_link('Nested Series Work', visible: :visible)

    # Collapse everything, then re-expand ONLY the outer volume via its toggle.
    find('#max_collapse').click
    expect(page).to have_link('Nested Series Work', visible: :hidden)

    outer_toggle = find("#cwrapper_#{outer_volume.id} .volume-collapse-toggle", match: :first)
    outer_toggle.click

    # The cascade reaches down through the series, so its work must become
    # visible again — not just the series header — and the series' own toggle
    # must be back in the expanded state to match.
    expect(page).to have_link('Nested Series Work', visible: :visible)
    expect(page).to have_no_css("#cwrapper_#{series.id} .volume-collapse-toggle.collapsed")
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
