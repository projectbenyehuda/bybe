# frozen_string_literal: true

require 'rails_helper'

# The sections navbar on a lexicon entry page sticks below the fixed site header. Its offset used
# to be a hardcoded 80px, which ignored the entry's breadcrumbs/actions row (whose buttons stay
# visible when scrolled) and the extra height an editor's header carries - so for editors the top
# of the navbar ended up hidden behind the header.
RSpec.describe 'Lexicon entry sticky navbar offset', :js, type: :system do
  let(:paragraph) { (['פסקה של ביוגרפיה, ארוכה דיה כדי שאפשר יהיה לגלול את העמוד.'] * 12).join(' ') }
  let(:bio) { Array.new(15) { "<p>#{paragraph}</p>" }.join("\n") }

  let(:person) { create(:lex_person, bio: bio) }
  let!(:entry) { create(:lex_entry, :person, title: 'Test Person', lex_item: person, status: :published) }

  before { skip 'WebDriver not available or misconfigured' unless webdriver_available? }

  # Vertical gap between the bottom of the fixed header and the top of the stuck navbar column.
  # Negative means the navbar is (partly) hidden behind the header.
  def navbar_top_minus_header_bottom
    page.evaluate_script(<<~JS)
      (function() {
        var header = document.getElementById('header');
        var nav = document.querySelector('.peach2-lexicon .side-menu-area');
        return nav.getBoundingClientRect().top - header.getBoundingClientRect().bottom;
      })()
    JS
  end

  # Lets the browser settle after a scroll: the layout's own scroll handler toggles the header's
  # .scrolled state, and the sticky offset is then recomputed in a requestAnimationFrame.
  def await_two_animation_frames
    page.evaluate_async_script(<<~JS)
      var done = arguments[0];
      requestAnimationFrame(function() { requestAnimationFrame(done); });
    JS
  end

  shared_examples 'sticks just below the header' do
    it 'keeps the navbar fully clear of the fixed header once stuck' do
      visit lexicon_entry_path(entry)
      expect(page).to have_css('#genrenav')

      page.execute_script('window.scrollTo(0, 1200);')
      expect(page).to have_css('body.scrolled') # set by the layout's scroll handler
      await_two_animation_frames

      gap = navbar_top_minus_header_bottom

      # Fully below the header (>= 0), and actually stuck to it rather than scrolled off.
      expect(gap).to be >= 0
      expect(gap).to be <= 30
    end
  end

  context 'when visiting as an anonymous visitor' do
    it_behaves_like 'sticks just below the header'
  end

  context 'when visiting as a lexicon editor' do
    before { login_as_lexicon_editor }

    it 'shows the editor actions row inside the fixed header' do
      visit lexicon_entry_path(entry)
      expect(page).to have_css('#header #header-lexicon-entry .entry-top-actions', text: I18n.t(:edit))
    end

    it_behaves_like 'sticks just below the header'
  end
end
