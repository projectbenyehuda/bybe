# frozen_string_literal: true

require 'rails_helper'

# Holds ManifestationController#snippets open at the server, so an example can assert on
# the loading mask while a request is provably still in the air rather than racing it.
#
# The Capybara server runs in this process, so a stub set in an example reaches it -- but
# on another thread, hence the handshake: the server thread announces itself and parks in
# #hold, the example thread waits for that announcement with #await, and lets the action
# through with #release.
class SnippetsGate
  def initialize(timeout)
    @timeout = timeout
    @arrivals = Queue.new
    @mutex = Mutex.new
    @cv = ConditionVariable.new
    @released = false
  end

  # Server thread: announce this request and park until the example releases it. Falls
  # through after `timeout` so a failing example cannot wedge the suite.
  def hold
    @arrivals << true
    @mutex.synchronize { @cv.wait(@mutex, @timeout) unless @released }
  end

  # Example thread: block until a request has actually reached the held action.
  def await
    raise 'no snippets request reached the controller' if @arrivals.pop(timeout: @timeout).nil?
  end

  # Example thread: let every parked request, and any that follow, complete.
  def release
    @mutex.synchronize do
      @released = true
      @cv.broadcast
    end
  end
end

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
      create(:manifestation, title: 'Alpha Poem', status: :published, author: author, orig_lang: 'he',
                             markdown: 'The opening line of the Alpha poem.')
    end
  end
  let(:story) do
    Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Beta Story', status: :published, author: author, orig_lang: 'he',
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

  # Holds the snippets action open; see SnippetsGate. `status` lets an example
  # exercise the failure path instead of the real response.
  def delay_snippets(status: nil, timeout: 10)
    gate = SnippetsGate.new(timeout)

    # rubocop:disable RSpec/AnyInstance -- the controller instance is the server's, not ours
    allow_any_instance_of(ManifestationController).to receive(:snippets).and_wrap_original do |orig, *args|
      gate.hold

      if status.nil?
        orig.call(*args)
      else
        orig.receiver.render(json: {}, status: status)
      end
    end
    # rubocop:enable RSpec/AnyInstance

    gate
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

  # The flat list is unpaginated, so fetching the excerpts of a prolific author can
  # take a couple of seconds with nothing on screen to show for it (bead 11x).
  it 'masks the page while the excerpts are being fetched, and unmasks once they are in' do
    snippets = delay_snippets
    visit authority_path(author)
    choose_sort('title')
    expect(page).to have_css('#sorted_card .manifestation-node', minimum: 2)

    find('#tocmode_snippets').click

    # With the request parked at the controller the page cannot move on, so the
    # state below is what the reader is left looking at, not a moment we caught.
    snippets.await

    expect(page).to have_css('#PopupMask')
    expect(page).to have_css('#spinnerdiv', visible: :visible)
    # Nothing to read yet: that is precisely what the mask is there to cover.
    expect(page).to have_no_css('.toc-snippet', visible: :all)

    snippets.release

    expect(page).to have_css('.toc-snippet', count: 2, wait: 10)
    expect(page).to have_no_css('#PopupMask')
    expect(page).to have_css('#spinnerdiv', visible: :hidden)
  end

  it 'takes the mask down even when the excerpt request fails' do
    snippets = delay_snippets(status: :internal_server_error)
    visit authority_path(author)
    choose_sort('title')
    expect(page).to have_css('#sorted_card .manifestation-node', minimum: 2)

    find('#tocmode_snippets').click
    snippets.await

    expect(page).to have_css('#PopupMask')
    expect(page).to have_css('#spinnerdiv', visible: :visible)

    snippets.release

    # No excerpts to show, but the reader must not be left staring at a masked page.
    expect(page).to have_no_css('#PopupMask', wait: 10)
    expect(page).to have_css('#spinnerdiv', visible: :hidden)
    expect(page).to have_no_css('.toc-snippet', visible: :all)
  end

  it 'heads each excerpt with the work\'s metadata' do
    visit authority_path(author)
    choose_sort('title')
    find('#tocmode_snippets').click
    expect(page).to have_css('.toc-snippet', count: 2)

    within(first('.toc-snippet .toc-snippet-meta')) do
      expect(page).to have_content("#{I18n.t(:word_count)}: 7")
      expect(page).to have_link('A Volume')
      # the work is this authority's own, so naming them here would add nothing
      expect(page).to have_no_content(author.name)
    end
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
