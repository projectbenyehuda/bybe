# frozen_string_literal: true

require 'rails_helper'

# The donation popup on /page/donate is an iframe modal injected by IsraelGives'
# third-party IGModal.js. Their stylesheet gives it z-index 1050 (backdrop 1040),
# which sits *below* our sticky #header (z-index 2000), so the top of the popup —
# including its close button — used to be hidden behind the header.
#
# We deliberately do not load the third-party script in tests (external network,
# flaky). Instead we reproduce the markup igModal.prototype.igAddHtml builds and
# the upstream IGmodal.css declarations the stacking depends on, then assert our
# override in application.scss wins.
RSpec.describe 'IsraelGives donation popup stacking', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  # Verbatim subset of https://www.israelgives.org/Content/IGModal/IGmodal.css
  let(:upstream_ig_css) do
    <<~CSS
      .ig-modal { position: fixed; top: 0; right: 0; bottom: 0; left: 0;
                  z-index: 1050; display: none; overflow: hidden; outline: 0; }
      .ig-modal.ig-show { display: block !important; }
      .ig-modal-backdrop { position: fixed; top: 0; right: 0; bottom: 0; left: 0;
                           z-index: 1040; background-color: #000; }
      .ig-modal-backdrop.ig-show { opacity: .5; display: block !important; }
    CSS
  end

  let!(:donate_page) do
    create(
      :static_page,
      tag: 'donate-popup-stacking',
      title: 'תמיכה כספית בפרויקט בן־יהודה',
      body: '<div class="btn linky ig_open_modal">לחצ/י לתרומה | Donate Now</div>'
    )
  end

  # Mirrors what IGModal.js appends to <body> when the donate button is clicked.
  def open_ig_modal
    page.execute_script(<<~JS, upstream_ig_css)
      var style = document.createElement('style');
      style.textContent = arguments[0];
      document.head.appendChild(style);

      var backdrop = document.createElement('div');
      backdrop.id = 'igBbackdrop';
      backdrop.className = 'ig-modal-backdrop ig-show';
      document.body.appendChild(backdrop);

      var modal = document.createElement('div');
      modal.id = 'igModal';
      modal.className = 'ig-modal ig-fade ig-show';
      modal.setAttribute('role', 'dialog');
      document.body.appendChild(modal);
    JS
  end

  # id of whatever is painted topmost at the centre of the sticky header
  def topmost_element_id_over_header
    page.evaluate_script(<<~JS)
      (function () {
        var rect = document.getElementById('header').getBoundingClientRect();
        var el = document.elementFromPoint(rect.left + rect.width / 2,
                                           rect.top + rect.height / 2);
        return el ? el.id : null;
      })();
    JS
  end

  it 'paints the popup above the sticky header instead of behind it' do
    visit static_pages_by_tag_path(donate_page.tag)
    expect(page).to have_css('.ig_open_modal', wait: 5)

    open_ig_modal

    expect(page).to have_css('#igModal.ig-show', visible: true, wait: 5)
    expect(topmost_element_id_over_header).to eq('igModal')
  end

  it 'keeps a popup taller than the viewport scrollable rather than clipping it' do
    visit static_pages_by_tag_path(donate_page.tag)
    expect(page).to have_css('.ig_open_modal', wait: 5)

    open_ig_modal

    # IGModal.js never adds the .ig-modal-open body class its CSS keys scrolling
    # off, so without our override .ig-modal stays overflow: hidden.
    overflow_y = page.evaluate_script(
      "window.getComputedStyle(document.getElementById('igModal')).overflowY"
    )
    expect(overflow_y).to eq('auto')
  end
end
