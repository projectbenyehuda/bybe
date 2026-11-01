# frozen_string_literal: true

require 'rails_helper'

# Issue #1783: scrolling the author page must move the in-page navbar's highlight
# (.selected) to the section being read, not only clicking a navbar item.
describe 'Author navbar scrollspy', :js, type: :system do
  # One volume per role, each involving the author on the collection level, so the
  # navbar gets one scrollable section per role, each in its own role group. Roles
  # are chosen to avoid 'editor', whose volumes render collapsed (and so are short).
  let(:roles) { %w(author illustrator translator) }
  let(:author) { create(:authority, name: 'Scrollspy Author') }
  # The author role also gets a series of two volumes, listed (nested) in the
  # navbar under the author section, to exercise tracking inside a section.
  let(:series) { create(:collection, title: 'Scrollspy Series', collection_type: :volume_series) }
  let(:series_volumes) do
    Array.new(2) do |n|
      create_volume("Series volume #{n + 1}").tap do |volume|
        create(:collection_item, collection: series, item: volume, seqno: n + 1)
      end
    end
  end

  # A volume holding enough works to be taller than the (short) window.
  def create_volume(title)
    volume = create(:collection, title: title, collection_type: :volume)
    create_list(:manifestation, 10, status: :published).each_with_index do |manifestation, i|
      create(:collection_item, collection: volume, item: manifestation, seqno: i + 1)
    end
    volume
  end

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?

    Chewy.strategy(:atomic) do
      roles.each do |role|
        create(:involved_authority, authority: author, item: create_volume("Volume #{role}"), role: role)
      end
      create(:involved_authority, authority: author, item: series, role: 'author')
      series_volumes
    end

    # A short window, so every section is taller than the viewport and can be
    # scrolled up to where a navbar click would leave it.
    resize_window(1400, 600)
    visit authority_path(author)
    # wait for the page (and with it the navbar's script) to be in place
    find('.book-nav-full', visible: :visible)
    find('#browse_mainlist')
  end

  after { Chewy.massacre }

  # Scrolls the page so the given section sits where clicking its navbar item
  # leaves it (120px below the author header). Done twice, a couple of frames
  # apart, since the header shrinks once the page scrolls. Returns whether the
  # page could actually scroll that far (sections near the bottom may not).
  def scroll_section_to_reading_position(selector)
    page.evaluate_async_script(<<~JS, selector)
      var selector = arguments[0], done = arguments[arguments.length - 1];
      function desired() {
        return Math.round($(selector).offset().top - ($('#header-author').outerHeight() || 0) - 120);
      }
      window.scrollTo(0, desired());
      requestAnimationFrame(function() {
        requestAnimationFrame(function() {
          window.scrollTo(0, desired());
          requestAnimationFrame(function() {
            done(Math.abs(Math.round(window.pageYOffset) - desired()) <= 1);
          });
        });
      });
    JS
  end

  def selected_item_selector(scroll_target)
    ".book-nav-full .book-type.selected .truncate[data-scroll-target='#{scroll_target}']"
  end

  def spy_targets
    all('.book-nav-full .book-type .truncate[data-scroll-target]', visible: :all).pluck('data-scroll-target')
  end

  it 'renders one navbar section per role, each with a scroll target in the TOC' do
    expect(spy_targets).to eq(roles.map { |role| "#works-#{role}-collection-level" })
    spy_targets.each { |target| expect(page).to have_css(target) }
  end

  it 'highlights the first section on load' do
    expect(page).to have_css(selected_item_selector(spy_targets.first))
    expect(page).to have_css('.book-nav-full .book-type.selected', count: 1)
  end

  it 'moves the highlight to each section as the page is scrolled down and back up' do
    targets = spy_targets
    reachable = targets.select { |target| scroll_section_to_reading_position(target) }
    expect(reachable.size).to be >= 2, "only #{reachable.inspect} of #{targets.inspect} could be scrolled into place"

    (reachable + reachable.reverse).each do |target|
      scroll_section_to_reading_position(target)

      expect(page).to have_css(selected_item_selector(target))
      expect(page).to have_css('.book-nav-full .book-type.selected', count: 1)
      # the role group containing the section is highlighted too, and only it
      group = find(selected_item_selector(target)).ancestor('.nav-book-group')
      expect(group).to match_css('.selected')
      expect(page).to have_css('.book-nav-full .nav-book-group.selected', count: 1)
    end
  end

  it 'highlights the last section once the page is scrolled to the bottom' do
    page.scroll_to(:bottom)

    expect(page).to have_css(selected_item_selector(spy_targets.last))
    expect(page).to have_css('.book-nav-full .book-type.selected', count: 1)
  end

  it 'returns the highlight to the first section when scrolled back to the top' do
    page.scroll_to(:bottom)
    expect(page).to have_css(selected_item_selector(spy_targets.last))

    page.scroll_to(:top)

    expect(page).to have_css(selected_item_selector(spy_targets.first))
    expect(page).to have_css('.book-nav-full .book-type.selected', count: 1)
  end

  it 'keeps following the scroll after a navbar item was clicked' do
    # Triggered through jQuery: what matters here is the navbar's own click handler,
    # and at this window height the sticky navbar may not fit for a native click.
    page.execute_script('$(arguments[0]).click()',
                        ".book-nav-full .truncate[data-scroll-target='#{spy_targets.last}']")
    # The click scrolls (animated, after the navbar collapse animation) down to the
    # section; let that finish so it does not fight the scroll back up below.
    wait_until_scrolled
    page.document.synchronize(Capybara.default_max_wait_time, errors: [Capybara::ExpectationNotMet]) do
      raise Capybara::ExpectationNotMet, 'scroll animation still running' if page.evaluate_script(
        "$('html, body').is(':animated')"
      )
    end
    expect(page).to have_css(selected_item_selector(spy_targets.last))

    page.scroll_to(:top)

    expect(page).to have_css(selected_item_selector(spy_targets.first))
    expect(page).to have_css('.book-nav-full .book-type.selected', count: 1)
  end

  # Below 992px only the thin navbar shows; the full one is hidden (so not synced on
  # scroll) until the reader expands it, at which point it must catch up.
  it 'highlights the current section when the mobile navbar is expanded' do
    resize_window(800, 600)
    find('.book-nav-thin', visible: :visible)
    expect(page).to have_css('.book-nav-full', visible: :hidden)

    targets = spy_targets
    target = targets.drop(1).find { |t| scroll_section_to_reading_position(t) }
    expect(target).not_to be_nil, "none of #{targets.drop(1).inspect} could be scrolled into place"
    scroll_section_to_reading_position(target)

    page.execute_script("$('.book-nav-thin .horizontal-collapse-expand').click()")

    expect(page).to have_css('.book-nav-full.mobile-expanded', visible: :visible)
    expect(page).to have_css(selected_item_selector(target))
    expect(page).to have_css('.book-nav-full .book-type.selected', count: 1)
  end

  describe 'collections inside an expanded section' do
    def selected_chapter_selector(collection)
      ".book-nav-full .nav-link-chapter.selected[data-scroll-target='#cwrapper_#{collection.id}']"
    end

    it 'highlights the innermost collection being read, within its section' do
      series_volumes.each do |volume|
        expect(scroll_section_to_reading_position("#cwrapper_#{volume.id}")).to be(true)

        # the volume, not the series containing it
        expect(page).to have_css(selected_chapter_selector(volume))
        expect(page).to have_css('.book-nav-full .nav-link-chapter.selected', count: 1)
        expect(page).to have_css(selected_item_selector('#works-author-collection-level'))
      end
    end

    it 'moves the collection highlight away when scrolling to another section' do
      volume = series_volumes.first
      scroll_section_to_reading_position("#cwrapper_#{volume.id}")
      expect(page).to have_css(selected_chapter_selector(volume))

      page.scroll_to(:top)
      expect(page).to have_no_css(selected_chapter_selector(volume))
    end

    it 'ignores the collections of a collapsed section, and tracks them again once expanded' do
      volume = series_volumes.first
      scroll_section_to_reading_position("#cwrapper_#{volume.id}")
      expect(page).to have_css(selected_chapter_selector(volume))

      page.execute_script("$('#collection-author-collapse').collapse('hide')")
      expect(page).to have_css('#collection-author-collapse', visible: :hidden)
      expect(page).to have_no_css('.book-nav-full .nav-link-chapter.selected', visible: :all)
      # the section itself is still the one being read
      expect(page).to have_css(selected_item_selector('#works-author-collection-level'))

      page.execute_script("$('#collection-author-collapse').collapse('show')")
      expect(page).to have_css(selected_chapter_selector(volume))
    end
  end
end
