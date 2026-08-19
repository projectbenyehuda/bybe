# frozen_string_literal: true

require 'rails_helper'

# The "latest works by this author" pane on a public lexicon entry has a title long enough to
# overflow the narrow entry sidebar. `.headline-2-v02` truncates with an ellipsis by default,
# which cut the title off; it must wrap onto a second line instead.
RSpec.describe 'Latest-works pane title', :js, type: :system do
  let(:authority) { create(:authority, status: :published) }
  let(:person) { create(:lex_person, authority: authority) }
  let!(:entry) { create(:lex_entry, :person, title: 'Test Person', lex_item: person, status: :published) }

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    visit lexicon_entry_path(entry)
  end

  it 'wraps the pane title rather than clipping it' do
    expect(page).to have_css('.author-whats-new-content p.headline-2-v02')

    metrics = page.evaluate_script(<<~JS)
      (function() {
        var el = document.querySelector('.author-whats-new-content p.headline-2-v02');
        var style = window.getComputedStyle(el);
        return {
          scrollWidth: el.scrollWidth,
          clientWidth: el.clientWidth,
          whiteSpace: style.whiteSpace,
          textOverflow: style.textOverflow
        };
      })()
    JS

    expect(metrics['whiteSpace']).not_to eq 'nowrap'
    expect(metrics['textOverflow']).not_to eq 'ellipsis'
    # the whole title fits horizontally: nothing is cut off
    expect(metrics['scrollWidth']).to be <= metrics['clientWidth'] + 1
  end
end
