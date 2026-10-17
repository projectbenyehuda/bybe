# frozen_string_literal: true

require 'rails_helper'

# The work page's mobile toolbar row: reading-mode button, download, like, bookmark,
# the "more" menu and the chapter-jump button. The download, like and bookmark glyphs
# are 18px glyphs in the 26px box .by-icon-v02 reserves against layout shift, and they
# rendered at the top of that box, ~5px above the rest of the row. Download used to be
# hidden in the "more" menu; it now sits in the row between reading mode and like.
describe 'Manifestation mobile toolbar', :js, :narrow_viewport, type: :system do
  let(:manifestation) do
    m = create(:manifestation, markdown: "## Chapter 1\n\nText one.\n\n## Chapter 2\n\nText two.\n",
                               status: :published)
    m.recalc_heading_lines
    m.save!
    m
  end

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    resize_window(390, 844)
    visit manifestation_path(manifestation)
  end

  # Vertical centre of each control in the row. For glyphs written as text we measure the
  # glyph's own line box (via a Range); the like and bookmark glyphs are ::before content,
  # which a Range cannot reach, so for those (and the download icon) we check that the
  # glyph's line box fills its element (line-height == height) and use the element's centre.
  def row_metrics
    page.evaluate_script(<<~JS)
      (function () {
        var row = document.querySelector('.chapters-and-icons-mobile');
        function centre(r) { return r.top + r.height / 2; }
        function glyphCentre(el) {
          var range = document.createRange();
          range.selectNodeContents(el);
          return centre(range.getBoundingClientRect());
        }
        var icons = {};
        ['.download', '.like', '.bookmark_button'].forEach(function (sel) {
          var el = row.querySelector('.icons-group-v02 > ' + sel);
          var cs = getComputedStyle(el);
          icons[sel] = { centre: centre(el.getBoundingClientRect()),
                         lineHeight: parseFloat(cs.lineHeight), height: el.getBoundingClientRect().height };
        });
        return {
          readmode: glyphCentre(row.querySelector('.reading-mode-icon-btn-v02 .by-icon-v02')),
          more: glyphCentre(row.querySelector('#text-nav-more .by-icon-v02')),
          chapters: centre(row.querySelector('#chapter_mobile_dropdown button').getBoundingClientRect()),
          icons: icons
        };
      })()
    JS
  end

  it 'aligns all the toolbar icons with the chapter-jump button' do
    expect(page).to have_css('.chapters-and-icons-mobile .icons-group-v02 > .download')
    metrics = row_metrics
    reference = metrics['chapters']

    expect(metrics['readmode']).to be_within(1.5).of(reference)
    expect(metrics['more']).to be_within(1.5).of(reference)
    metrics['icons'].each do |selector, icon|
      expect(icon['lineHeight']).to be_within(0.5).of(icon['height']), "#{selector} glyph is not centred in its box"
      expect(icon['centre']).to be_within(1.5).of(reference), "#{selector} is off the row's centre line"
    end
  end

  it 'shows the download button between reading mode and like, not in the more menu' do
    readmode = find('.chapters-and-icons-mobile .reading-mode-icon-btn-v02').rect
    download = find('.chapters-and-icons-mobile .icons-group-v02 > .download').rect
    like = find('.chapters-and-icons-mobile .icons-group-v02 > .like').rect

    # RTL row: reading mode is rightmost, then download, then like.
    expect(download.x + download.width).to be <= readmode.x
    expect(like.x + like.width).to be <= download.x
    expect(page).to have_no_css('#text-menu-more .download', visible: :all)
  end

  it 'opens the download dialog from the toolbar download button' do
    find('.chapters-and-icons-mobile .icons-group-v02 > .download').click
    expect(page).to have_css('#downloadDlg', visible: :visible)
  end
end
