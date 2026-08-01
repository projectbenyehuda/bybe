# frozen_string_literal: true

require 'rails_helper'

# The verified/total tally used to sit at the far end of the works section header,
# next to the proposed-matches button, which read as if it belonged to that button.
RSpec.describe 'Works section header layout', :js, type: :system do
  let(:person) { create(:lex_person) }
  let(:entry) { create(:lex_entry, :person, status: :draft, lex_item: person) }
  let!(:work) { create(:lex_person_work, person: person, title: 'A Work', seqno: 1) }

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
    entry.start_verification!('test@example.com')
    visit lexicon_verification_path(entry)
  end

  it 'renders the tally closer to the section title than to the proposed-matches button' do
    expect(page).to have_css('#section-works .section-header .verification-badge', text: '0/1')

    distances = page.evaluate_script(<<~JS)
      (function() {
        var header = document.querySelector('#section-works .section-header');
        var gap = function(a, b) {
          var ra = a.getBoundingClientRect(), rb = b.getBoundingClientRect();
          return Math.max(rb.left - ra.right, ra.left - rb.right);
        };
        var title = header.querySelector('h5');
        var badge = header.querySelector('.verification-badge');
        var button = header.querySelector('button');
        return { toTitle: gap(title, badge), toButton: gap(badge, button) };
      })()
    JS

    expect(distances['toTitle']).to be < distances['toButton']
    # "adequately spaced": not glued to the title either
    expect(distances['toTitle']).to be >= 8
  end
end
