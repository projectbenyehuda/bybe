# frozen_string_literal: true

require 'rails_helper'

# The destructive delete button used to sit right next to edit/verify, making a
# mis-click easy. It is now pushed to the opposite edge of the card while the
# other actions stay packed at the start of the row.
RSpec.describe 'Delete button placement in verification cards', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
  end

  let(:entry) { create(:lex_entry, :person, status: :draft) }
  let(:person) { entry.lex_item }
  let!(:citation) { create(:lex_citation, person: person, title: 'A cited work') }
  let!(:link) { create(:lex_link, item: person, url: 'https://example.com/somewhere') }

  # Horizontal geometry of a card's action row, in viewport pixels.
  def action_row_geometry(card_selector, delete_selector)
    page.evaluate_script(<<~JS)
      (function() {
        var card = document.querySelector('#{card_selector}');
        var actions = card.querySelector('.citation-actions, .link-actions');
        var del = card.querySelector('#{delete_selector}');
        var others = Array.prototype.filter.call(
          actions.children, function(el) { return el !== del; }
        );
        var rects = others.map(function(el) { return el.getBoundingClientRect(); });
        return {
          actions_left: actions.getBoundingClientRect().left,
          actions_right: actions.getBoundingClientRect().right,
          delete_left: del.getBoundingClientRect().left,
          delete_right: del.getBoundingClientRect().right,
          others_left: Math.min.apply(null, rects.map(function(r) { return r.left; })),
          others_right: Math.max.apply(null, rects.map(function(r) { return r.right; })),
          others_count: others.length
        };
      })()
    JS
  end

  shared_examples 'a card with the delete button on the far side' do |card_selector, delete_selector|
    it 'keeps edit/verify on the left and pushes delete to the right' do
      visit lexicon_verification_path(entry)
      expect(page).to have_css("#{card_selector} #{delete_selector}", wait: 5)

      geo = action_row_geometry(card_selector, delete_selector)

      # Sanity: the row really does hold the other actions besides delete.
      expect(geo['others_count']).to be >= 2

      # The non-destructive actions hug the left edge of the row...
      expect(geo['others_left'] - geo['actions_left']).to be < 2

      # ...while delete hugs the right edge...
      expect(geo['actions_right'] - geo['delete_right']).to be < 2

      # ...with real separation between the two groups, not the 0.5rem flex gap.
      expect(geo['delete_left'] - geo['others_right']).to be > 20
    end
  end

  it_behaves_like 'a card with the delete button on the far side',
                  '.citation-card', 'a.delete-citation'

  it_behaves_like 'a card with the delete button on the far side',
                  '.link-card', 'a.delete-link'
end
