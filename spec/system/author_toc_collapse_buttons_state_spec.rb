# frozen_string_literal: true

require 'rails_helper'

# The Collapse all / Expand all buttons in the Authority TOC action bar must
# reflect the list's current state: whichever action would still change
# something is the primary (filled) button, and the one that would be a no-op is
# disabled. In a mixed state both apply and Collapse all stays primary.
describe 'Author TOC collapse/expand buttons state', :js do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  let!(:author) { create(:authority, name: 'Test Author') }

  # The non-primary (outline) style is the .by-button-secondary-v02 class.
  let(:collapse_btn) { '#max_collapse' }
  let(:expand_btn) { '#expand-all' }

  let!(:volumes) do
    Chewy.strategy(:atomic) do
      %w(First Second).map do |name|
        volume = create(:collection, title: "#{name} Volume", collection_type: :volume)
        work = create(:manifestation, title: "Work in #{name} Volume", status: :published, author: author)
        create(:collection_item, collection: volume, item: work)
        create(:involved_authority, authority: author, item: volume, role: 'editor')
        volume
      end
    end
  end

  after { Chewy.massacre }

  it 'starts with Expand all disabled, everything being expanded' do
    visit authority_path(author)

    expect(page).to have_css('#browse_mainlist .volume-collapse-toggle')
    expect(page).to have_css("#{collapse_btn}:not(:disabled):not(.by-button-secondary-v02)")
    expect(page).to have_css("#{expand_btn}:disabled.by-button-secondary-v02")
  end

  it 'swaps the primary button once everything is collapsed, and back again' do
    visit authority_path(author)
    expect(page).to have_css('#browse_mainlist .volume-collapse-toggle')

    find(collapse_btn).click

    # Nothing left to collapse: Collapse all goes disabled/secondary and Expand
    # all becomes the primary action.
    expect(page).to have_css("#{collapse_btn}:disabled.by-button-secondary-v02")
    expect(page).to have_css("#{expand_btn}:not(:disabled):not(.by-button-secondary-v02)")

    find(expand_btn).click

    expect(page).to have_css("#{collapse_btn}:not(:disabled):not(.by-button-secondary-v02)")
    expect(page).to have_css("#{expand_btn}:disabled.by-button-secondary-v02")
  end

  it 'enables both buttons while the list is in a mixed state' do
    visit authority_path(author)

    # At least two toggles, so collapsing one always leaves another expanded.
    expect(page).to have_css('#browse_mainlist .volume-collapse-toggle', minimum: 2)
    find('#browse_mainlist .volume-collapse-toggle', match: :first).click

    # Both actions still do something; Collapse all remains the primary one.
    expect(page).to have_css("#{collapse_btn}:not(:disabled):not(.by-button-secondary-v02)")
    expect(page).to have_css("#{expand_btn}:not(:disabled).by-button-secondary-v02")
  end

  it 'tracks state driven by the individual toggles alone' do
    visit authority_path(author)
    expect(page).to have_css('#browse_mainlist .volume-collapse-toggle')

    # Collapsing every card one by one must leave the buttons in the same state
    # as pressing Collapse all.
    all('#browse_mainlist .volume-collapse-toggle').each(&:click)

    expect(page).to have_css("#{collapse_btn}:disabled.by-button-secondary-v02")
    expect(page).to have_css("#{expand_btn}:not(:disabled):not(.by-button-secondary-v02)")
  end

  it 'takes both buttons out of the flat list, which has no collapsible cards' do
    visit authority_path(author)
    expect(page).to have_css('#browse_mainlist .volume-collapse-toggle')

    # Switching to a flat sort rebuilds the list as a single card of works.
    find("#sort_by option[value='title']").select_option

    expect(page).to have_no_css('#browse_mainlist .volume-collapse-toggle')
    # The action bar swaps them out for the list/summaries switch entirely, and
    # they are left disabled underneath.
    expect(page).to have_no_css(collapse_btn)
    expect(page).to have_no_css(expand_btn)
    expect(page).to have_css("#{collapse_btn}:disabled", visible: :hidden)
    expect(page).to have_css("#{expand_btn}:disabled", visible: :hidden)
  end
end
