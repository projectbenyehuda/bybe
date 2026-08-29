# frozen_string_literal: true

require 'rails_helper'

# The reading-mode control panel's item navigator (shared/_readmode_nav) used to be a native
# <select> inside a 210px panel. A <select>'s options cannot wrap in any browser, so long chapter
# and collection-item titles were clipped. It is now a list of divs in a widened panel.
describe 'Reading mode navigator', :js, type: :system do
  let(:long_title) { 'מסע ארוך מאוד אל קצה העולם ובחזרה, פרק ראשון שבו מתגלה סוד' }
  let(:body) { (['מילה ' * 40] * 30).join("\n\n") }

  let!(:first_text) do
    Chewy.strategy(:atomic) { create(:manifestation, title: long_title, markdown: body, status: :published) }
  end

  let!(:second_text) do
    Chewy.strategy(:atomic) { create(:manifestation, title: 'שיר קצר', markdown: body, status: :published) }
  end

  let!(:collection) do
    Chewy.strategy(:atomic) do
      col = create(:collection, title: 'Readable Collection', collection_type: :volume)
      create(:collection_item, collection: col, item: first_text, seqno: 1)
      create(:collection_item, collection: col, item: second_text, seqno: 2)
      col
    end
  end

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    resize_window(1400, 900)
  end

  after { Chewy.massacre }

  def box(selector)
    page.evaluate_script(<<~JS).symbolize_keys
      (function () {
        var r = document.querySelector('#{selector}').getBoundingClientRect();
        return { left: r.left, right: r.right, top: r.top, width: r.width, height: r.height };
      })()
    JS
  end

  # Left edge of the first paragraph's own text, which is what the fixed control panel would
  # cover. Measured from a Range so it is the text's extent, not its block's full width.
  def text_left_edge
    page.evaluate_script(<<~JS)
      (function () {
        var p = document.querySelector('#actualtext p') || document.querySelector('#actualtext');
        var r = document.createRange();
        r.selectNodeContents(p);
        return r.getBoundingClientRect().left;
      })()
    JS
  end

  it 'wraps a long title in the closed control instead of clipping it' do
    visit collection_readmode_path(collection)
    expect(page).to have_css('#rm_nav_current')

    expect(page).to have_css('.rm-nav-current-label', text: long_title)
    # a single line of this font is ~22px; wrapping this title takes several
    expect(box('#rm_nav_current')[:height]).to be > 40
  end

  it 'wraps long titles in the open list and keeps the list inside the panel' do
    visit collection_readmode_path(collection)
    find('#rm_nav_current').click

    expect(page).to have_css('.rm-nav-list.open')
    items = page.all('.rm-nav-item')
    expect(items.map(&:text)).to eq([long_title, 'שיר קצר'])

    long_item = box('.rm-nav-item:first-child')
    short_item = box('.rm-nav-item:last-child')
    expect(long_item[:height]).to be > short_item[:height] # i.e. it wrapped rather than clipped
    expect(long_item[:width]).to be <= box('.rm-control-panel')[:width]
  end

  it 'scrolls to the item picked from the list and remembers it as current' do
    visit collection_readmode_path(collection)
    find('#rm_nav_current').click
    page.all('.rm-nav-item').last.click

    expect(page).to have_css('.rm-nav-current-label', text: 'שיר קצר')
    expect(wait_until_scrolled(wait: 10)).to be > 0
    expect(page).to have_no_css('.rm-nav-list.open') # picking an item closes the list
  end

  it 'steps between items with the previous/next buttons' do
    visit collection_readmode_path(collection)
    expect(page).to have_css('#next_rm_item')

    find('#next_rm_item').click
    expect(page).to have_css('.rm-nav-current-label', text: 'שיר קצר')
    expect(wait_until_scrolled(wait: 10)).to be > 0

    find('#prev_rm_item').click
    expect(page).to have_css('.rm-nav-current-label', text: long_title)
  end

  it 'keeps the collection text clear of the fixed control panel' do
    visit collection_readmode_path(collection)
    expect(page).to have_css('.rm-control-panel', visible: :visible)

    expect(text_left_edge).to be > box('.rm-control-panel')[:right]
  end

  context 'when reading a work rather than a collection' do
    let!(:chaptered_work) do
      Chewy.strategy(:atomic) do
        create(:manifestation, title: 'יצירה עם פרקים', status: :published,
                               markdown: "## #{long_title}\n\n#{body}\n\n## פרק שני\n\n#{body}\n")
      end
    end

    it 'shows the same navigator over the work chapters, and wraps their titles' do
      visit manifestation_readmode_path(chaptered_work)
      expect(page).to have_css('#rm_nav_current')

      expect(page).to have_no_css('select#chapters') # the native select it replaced
      find('#rm_nav_current').click
      expect(page).to have_css('.rm-nav-item', count: 2)
      expect(box('.rm-nav-item:first-child')[:height]).to be > box('.rm-nav-item:last-child')[:height]
    end

    it 'steps between chapters and keeps the text clear of the control panel' do
      visit manifestation_readmode_path(chaptered_work)
      expect(page).to have_css('#next_rm_item')

      expect(text_left_edge).to be > box('.rm-control-panel')[:right]

      find('#next_rm_item').click
      expect(page).to have_css('.rm-nav-current-label', text: 'פרק שני')
      expect(wait_until_scrolled(wait: 10)).to be > 0
    end
  end
end
