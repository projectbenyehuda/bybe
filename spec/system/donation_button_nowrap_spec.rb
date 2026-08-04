# frozen_string_literal: true

require 'rails_helper'

# Safari measures the Hebrew donate label wider than Chrome/Firefox do, so the
# button -- sized by a fixed min-width -- wrapped there while looking fine
# elsewhere. The label is now pinned to a single line regardless of metrics.
RSpec.describe 'Top-bar donation button', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  it 'never wraps its label, whatever the browser text metrics' do
    visit '/pby_volumes'

    expect(page).to have_css('.donation-area-v02 .donation-btn-v02', visible: :visible)

    metrics = page.evaluate_script(<<~JS)
      (function () {
        var btn = document.querySelector('.donation-area-v02 .donation-btn-v02');
        var cs = getComputedStyle(btn);
        return {
          whiteSpace: cs.whiteSpace,
          lineHeight: parseFloat(cs.lineHeight),
          height: btn.getBoundingClientRect().height,
          scrollWidth: btn.scrollWidth,
          clientWidth: btn.clientWidth
        };
      })()
    JS

    # The guarantee: the label cannot break onto a second line.
    expect(metrics['whiteSpace']).to eq('nowrap')
    # And as rendered here it is one line, with the text not clipped.
    expect(metrics['height']).to be < (metrics['lineHeight'] * 2)
    expect(metrics['scrollWidth']).to be <= metrics['clientWidth'] + 1
  end
end
