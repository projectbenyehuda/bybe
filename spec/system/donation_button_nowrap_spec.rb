# frozen_string_literal: true

require 'rails_helper'

# Safari measures the Hebrew donate label wider than Chrome/Firefox do, so the
# button -- sized by a fixed min-width -- wrapped there while looking fine
# elsewhere. The label is now pinned to a single line regardless of metrics.
RSpec.describe 'Top-bar donation button', :js, type: :system do
  # Measures the button against its own contents. "Slack" is how much of the
  # button's content box the icon and label do not occupy, taken as the span
  # from the leftmost to the rightmost of their client rects -- which already
  # accounts for the flex gap between them, so nothing here has to parse
  # `column-gap` (it computes to the keyword `normal` when no gap applies).
  # The label needs a Range because it is an anonymous flex item, with no
  # element of its own to measure.
  let(:measure_button_js) do
    <<~JS
      (function () {
        var btn = document.querySelector('.donation-area-v02 .donation-btn-v02');
        var cs = getComputedStyle(btn);
        var rects = [btn.querySelector('.by-icon-v02').getBoundingClientRect()];
        btn.childNodes.forEach(function (node) {
          if (node.nodeType !== Node.TEXT_NODE || !node.textContent.trim()) return;
          var range = document.createRange();
          range.selectNodeContents(node);
          rects.push(range.getBoundingClientRect());
        });
        var occupied = Math.max.apply(null, rects.map(function (r) { return r.right; })) -
          Math.min.apply(null, rects.map(function (r) { return r.left; }));
        var contentWidth = btn.clientWidth -
          parseFloat(cs.paddingLeft) - parseFloat(cs.paddingRight);
        return {
          whiteSpace: cs.whiteSpace,
          lineHeight: parseFloat(cs.lineHeight),
          height: btn.getBoundingClientRect().height,
          scrollWidth: btn.scrollWidth,
          clientWidth: btn.clientWidth,
          slack: contentWidth - occupied
        };
      })()
    JS
  end

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  it 'never wraps its label, whatever the browser text metrics' do
    visit '/pby_volumes'

    expect(page).to have_css('.donation-area-v02 .donation-btn-v02', visible: :visible)

    metrics = page.evaluate_script(measure_button_js)

    # The guarantee: the label cannot break onto a second line.
    expect(metrics['whiteSpace']).to eq('nowrap')
    # And as rendered here it is one line, with the text not clipped.
    expect(metrics['height']).to be < (metrics['lineHeight'] * 2)
    expect(metrics['scrollWidth']).to be <= metrics['clientWidth'] + 1
    # The button is also wide enough to absorb a browser that measures the bold
    # label a few percent wider: Alef is served in weight 400 only, so the bold
    # label is synthesised, and macOS emboldens more than Linux/Windows.
    expect(metrics['slack']).to be >= 8
  end
end
