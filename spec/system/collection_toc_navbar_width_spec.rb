# frozen_string_literal: true

require 'rails_helper'

# Regression for the side table-of-contents navbar (#chapternav) overflowing its
# .side-nav-col column and overlapping the work-info card on Collection#show.
#
# Root cause: `#chapternav { width: min-content }` grew the nav to fit the
# longest un-truncated item, defeating the ellipsis truncation on
# .nav-chapter-name. With long item titles (common for periodical article
# titles) the nav ballooned well past its 155px column and drew on top of the
# content card. The fix caps `.side-nav-col #chapternav` to `max-width: 100%`.
RSpec.describe 'Collection#show side TOC navbar width', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  # A collection with a single manifestation redirects to that manifestation, so
  # we need at least two items to exercise Collection#show. Titles are made long
  # on purpose: since .nav-chapter-name is white-space:nowrap, a long title makes
  # the nav's min-content wide enough to overflow the narrow column without the
  # max-width cap.
  let(:long_title_a) do
    'A deliberately very long collection item title that would overflow the narrow side nav column'
  end
  let(:long_title_b) do
    'Another exceedingly long collection item title also intended to overflow the side navigation'
  end

  let!(:manifestation_a) do
    Chewy.strategy(:atomic) do
      create(:manifestation, title: long_title_a, status: :published, markdown: 'content A')
    end
  end

  let!(:manifestation_b) do
    Chewy.strategy(:atomic) do
      create(:manifestation, title: long_title_b, status: :published, markdown: 'content B')
    end
  end

  # collection_type pinned to :volume: the factory samples it randomly, and a
  # :periodical uses a different layout. :volume renders the standard TOC navbar.
  let!(:collection) do
    Chewy.strategy(:atomic) do
      create(:collection, title: 'TOC Width Test Collection', collection_type: :volume,
                          manifestations: [manifestation_a, manifestation_b])
    end
  end

  after { Chewy.massacre }

  it 'keeps the TOC navbar within its column and off the content card' do
    visit collection_path(collection)

    # Wait for the navbar (and its items) to render.
    expect(page).to have_css('#chapternav .side-menu-item', wait: 10)

    rects = page.evaluate_script(<<~JS)
      (function () {
        function rect(sel) {
          var el = document.querySelector(sel);
          if (!el) { return null; }
          var r = el.getBoundingClientRect();
          return { left: r.left, right: r.right, width: r.width };
        }
        return {
          nav: rect('#chapternav'),
          col: rect('.side-nav-col'),
          card: rect('.work-info-card')
        };
      })();
    JS

    expect(rects['nav']).not_to be_nil
    expect(rects['col']).not_to be_nil
    expect(rects['card']).not_to be_nil

    # The nav must not be wider than its containing column (this is the bug:
    # without the fix it grew to ~355px inside a 155px column). Allow 1px slack
    # for sub-pixel rounding.
    expect(rects['nav']['width']).to be <= rects['col']['width'] + 1

    # And it must not overlap the content card. The page is RTL, so the nav sits
    # to the right of (higher x than) the card: nav.left >= card.right.
    expect(rects['nav']['left']).to be >= rects['card']['right']
  end
end
