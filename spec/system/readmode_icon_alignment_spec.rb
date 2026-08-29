# frozen_string_literal: true

require 'rails_helper'

# Regression test for bead by-l0f. The reading-mode buttons on the work page put
# an 18px ben-yehuda glyph inside the 26px box that .by-icon-v02 reserves to
# avoid layout shift, so the glyph rendered against the top of the button's
# purple background instead of lining up with the label beside it.
#
# The icon-only (mobile) button had the same problem on the horizontal axis: the
# RTL page's inherited text-align:right pinned the 18px glyph to the right edge
# of its 26px box, 4px off the centre of the purple square. That button now also
# appears on the collection page, so both pages are covered.
describe 'Reading mode icon alignment', :js, type: :system do
  let(:manifestation) { create(:manifestation) }

  let(:collection) do
    Chewy.strategy(:atomic) do
      col = create(:collection, title: 'Readable Collection', collection_type: :volume)
      create(:collection_item, collection: col, item: create(:manifestation, status: :published), seqno: 1)
      create(:collection_item, collection: col, item: create(:manifestation, status: :published), seqno: 2)
      col
    end
  end

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  after { Chewy.massacre }

  # Offsets, in CSS pixels, between the centre of the glyph's line box and the
  # centre of the button it sits in. Positive :v means the glyph is low,
  # positive :h means it is to the right of centre.
  #
  # The offsets must be measured from the glyph's own inline box (via a Range
  # over the span's text), not from the span's border box: the span is a fixed
  # 26x26 for CLS reasons and is itself centred in the button, so its box stays
  # centred even while the smaller line box inside it rides up or over.
  def icon_offsets_from_button_centre(button_selector)
    page.evaluate_script(<<~JS).symbolize_keys
      (function () {
        var btn = document.querySelector('#{button_selector}');
        var icon = btn.querySelector('.by-icon-v02');
        var range = document.createRange();
        range.selectNodeContents(icon);
        var g = range.getBoundingClientRect();
        var b = btn.getBoundingClientRect();
        return {
          v: (g.top + g.height / 2) - (b.top + b.height / 2),
          h: (g.left + g.width / 2) - (b.left + b.width / 2)
        };
      })()
    JS
  end

  it 'centres the glyph in the desktop reading-mode button' do
    resize_window(1400, 900)
    visit manifestation_path(manifestation)

    expect(page).to have_css('.reading-mode-btn-v02')
    expect(icon_offsets_from_button_centre('.reading-mode-btn-v02')[:v].abs).to be < 1.5
  end

  # The mobile button only exists below the 991px breakpoint -- above it the whole
  # .chapters-and-icons-mobile container is display:none, so this has to narrow the window
  # before visiting. :narrow_viewport buys the Chrome driver, which is the only one that will
  # size below 500px; it does not do the resizing.
  it 'centres the glyph in the work page mobile reading-mode icon button', :narrow_viewport do
    resize_window(390, 844)
    visit manifestation_path(manifestation)

    expect(page).to have_css('.reading-mode-icon-btn-v02')
    offsets = icon_offsets_from_button_centre('.reading-mode-icon-btn-v02')
    expect(offsets[:v].abs).to be < 1.5
    expect(offsets[:h].abs).to be < 1.5
  end

  it 'centres the glyph in the collection page mobile reading-mode icon button', :narrow_viewport do
    resize_window(390, 844)
    visit collection_path(collection)

    expect(page).to have_css('.work-page-top-icons-mobile .reading-mode-icon-btn-v02')
    offsets = icon_offsets_from_button_centre('.work-page-top-icons-mobile .reading-mode-icon-btn-v02')
    expect(offsets[:v].abs).to be < 1.5
    expect(offsets[:h].abs).to be < 1.5
  end
end
