# frozen_string_literal: true

require 'rails_helper'

# The layout's JS sets margin-top (header height + 25px) on *every* .top-element, and several
# views (collections/show among them) wrap their body in a second .top-element nested inside
# the layout's #content.top-element. That inner margin used to be invisible only because it
# collapsed into the outer one; the returning-visitor donation banner, rendered just before
# the yielded view, broke the collapse and left a ~250px band of blank space above the page's
# heading, which only went away when the banner was dismissed. See issue #1019.
RSpec.describe 'Returning-visitor donation banner spacing', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  let(:collection) do
    Chewy.strategy(:atomic) do
      coll = create(:collection, collection_type: :volume, title: 'אוסף לבדיקה')
      2.times { |i| coll.collection_items.create!(item: create(:manifestation, status: :published), seqno: i + 1) }
      coll
    end
  end

  let(:base_user) { create(:base_user) }

  # The banner shows every 4th visit; stub the count rather than creating Ahoy visits, since
  # the browser session itself gets tracked and would shift the count.
  def stub_base_user(visits_count)
    allow(base_user).to receive(:visits).and_return(instance_double(ActiveRecord::Relation, count: visits_count))
    # rubocop:disable RSpec/AnyInstance -- the controller instance is the server's, not ours
    allow_any_instance_of(ApplicationController).to receive(:base_user).and_return(base_user)
    # rubocop:enable RSpec/AnyInstance
  end

  # Distance in px between the bottom of the donation banner (or the top of the layout's
  # content container when there is no banner) and the top of the page's first card.
  def gap_above_content
    page.evaluate_script(<<~JS)
      (function() {
        var banner = document.getElementById('donban');
        var top = banner ? banner.getBoundingClientRect().bottom
                         : document.getElementById('content').getBoundingClientRect().top;
        return Math.round(document.querySelector('.work-info-card').getBoundingClientRect().top - top);
      })()
    JS
  end

  after { Chewy.massacre }

  it 'does not add a band of blank space above the heading when the banner is shown' do
    stub_base_user(3)
    visit collection_path(collection)

    expect(page).to have_css('#donban')
    # Only the .by-card-v02 top margin (15px) separates the banner from the content below it.
    expect(gap_above_content).to be < 40
  end

  it 'zeroes the duplicate top margin of a nested .top-element' do
    stub_base_user(3)
    visit collection_path(collection)

    expect(page).to have_css('#donban')
    nested_margin = page.evaluate_script(
      "getComputedStyle(document.querySelector('#content.top-element .top-element')).marginTop"
    )
    expect(nested_margin).to eq('0px')
  end

  it 'leaves the spacing above the heading unchanged when no banner is shown' do
    stub_base_user(1)
    visit collection_path(collection)

    expect(page).to have_no_css('#donban')
    expect(gap_above_content).to be < 40
  end
end
