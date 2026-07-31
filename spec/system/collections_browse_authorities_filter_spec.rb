# frozen_string_literal: true

require 'rails_helper'

# End-to-end coverage for the /collections browse "filter by authors" multiselect popup:
# picking authors in the popup must filter the list, and the selection must survive
# subsequent filter interactions (which resubmit the same form).
describe 'Collections browse authorities filter', :js do
  let!(:alice) { create(:authority, name: 'Alice Author') }
  let!(:bob) { create(:authority, name: 'Bob Author') }
  let!(:carol) { create(:authority, name: 'Carol Author') }

  let!(:alice_volume) do
    create(:collection, title: 'Alice Volume', collection_type: :volume, sort_title: 'alice volume').tap do |c|
      c.involved_authorities.create!(authority: alice, role: :author)
    end
  end
  let!(:bob_volume) do
    create(:collection, title: 'Bob Volume', collection_type: :volume, sort_title: 'bob volume').tap do |c|
      c.involved_authorities.create!(authority: bob, role: :author)
    end
  end
  let!(:carol_volume) do
    create(:collection, title: 'Carol Volume', collection_type: :volume, sort_title: 'carol volume').tap do |c|
      c.involved_authorities.create!(authority: carol, role: :author)
    end
  end

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?

    import_and_await(CollectionsIndex, [alice_volume, bob_volume, carol_volume])
  end

  after do
    Chewy.massacre
  end

  def select_authorities_in_popup(*authorities)
    find('#filters_panel .multi-name-sort span', text: I18n.t(:multiselect)).click
    expect(page).to have_css('#authoritiesDlg.show', wait: 5)

    authorities.each { |authority| find("#auth_#{authority.id}", visible: :all).click }

    click_button I18n.t(:add_authorities_to_filter)
  end

  it 'filters the list to the authors picked in the popup, and keeps the filter afterwards' do
    visit collections_browse_path
    expect(page).to have_css('#thelist', text: 'Carol Volume', wait: 5)

    select_authorities_in_popup(alice, bob)

    expect(page).to have_css('#thelist', text: 'Alice Volume', wait: 5)
    expect(page).to have_css('#thelist', text: 'Bob Volume')
    expect(page).to have_no_css('#thelist', text: 'Carol Volume')

    # A further filter interaction resubmits the form; both authorities must survive it.
    # Tick the "volume" collection type: its filter chip appearing tells us the second
    # round-trip has actually landed, so the assertions below can't pass on stale markup.
    find('#collection_type_volume', visible: :all).click
    volume_label = ApplicationController.helpers.textify_collection_type('volume')
    expect(page).to have_css('.filters', text: volume_label, wait: 5)

    expect(page).to have_css('#thelist', text: 'Alice Volume')
    expect(page).to have_css('#thelist', text: 'Bob Volume')
    expect(page).to have_no_css('#thelist', text: 'Carol Volume')
  end
end
