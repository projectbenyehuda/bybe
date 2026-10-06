# frozen_string_literal: true

require 'rails_helper'

# On mobile the author page's thin navbar is a sticky rail pinned to the right edge. The
# returning-visitor donation banner, rendered by the layout, used to extend underneath it,
# so the rail hid part of the banner's text. See issue #1757.
RSpec.describe 'Donation banner vs. author page side rail on mobile', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  after { Chewy.massacre }

  let(:author) { create(:authority, name: 'Test Author') }
  let(:base_user) { create(:base_user) }

  # The banner shows every 4th visit; stub the count rather than creating Ahoy visits.
  def stub_base_user(visits_count)
    allow(base_user).to receive(:visits).and_return(instance_double(ActiveRecord::Relation, count: visits_count))
    # rubocop:disable RSpec/AnyInstance -- the controller instance is the server's, not ours
    allow_any_instance_of(ApplicationController).to receive(:base_user).and_return(base_user)
    # rubocop:enable RSpec/AnyInstance
  end

  def rect_edge(selector, edge)
    page.evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().#{edge}")
  end

  it 'keeps the banner clear of the side rail at a mobile width' do
    Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Test Work', status: :published, author: author)
    end
    stub_base_user(3)
    page.driver.browser.manage.window.resize_to(400, 900)
    visit authority_path(author)

    expect(page).to have_css('#donban')
    expect(page).to have_css('.author-side-nav-col .book-nav-thin')

    # RTL layout: the rail is at the right edge, so the banner must end where the rail begins.
    expect(rect_edge('#donban', 'right')).to be <= rect_edge('.author-side-nav-col', 'left')
  end
end
