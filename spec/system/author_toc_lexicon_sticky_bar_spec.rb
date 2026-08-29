# frozen_string_literal: true

require 'rails_helper'

# The Authority TOC's sticky action bar (collapse/expand, sort) acts on the works
# list. For an authority with a published lexicon entry the lexicon block sits
# below that list, and once the reader has scrolled into it the bar is left
# hovering over content none of its actions apply to -- so it gets out of the way,
# and comes back on the way up.
describe 'Authority TOC sticky bar over the lexicon block', :js do
  # Lazy `let` (not `let!`) so the WebDriver skip in the before hook can
  # short-circuit without running the DB + Chewy setup when Chrome is unavailable.
  let(:author) { create(:authority, name: 'Lexicon Author') }
  let(:volume) { create(:collection, title: 'A Volume', collection_type: :volume) }

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?

    poem = Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Alpha Poem', status: :published, author: author, orig_lang: 'he',
                             markdown: 'The opening line of the Alpha poem.')
    end
    create(:collection_item, collection: volume, item: poem)
    create(:involved_authority, authority: author, item: volume, role: 'editor')
  end

  after { Chewy.massacre }

  def add_lexicon_entry
    person = create(:lex_person, authority: author, bio: 'A lexicon biography of the author.')
    create(:lex_entry, title: author.name, lex_item: person, status: :published)
  end

  # Puts the top of the lexicon block's first card at the top of the viewport,
  # i.e. well past the middle, which is what the bar reacts to.
  def scroll_to_lexicon
    page.execute_script("document.querySelector('.peach2-lexicon .by-card-v02').scrollIntoView(true)")
  end

  it 'hides the bar once the first lexicon card is past mid-viewport, and shows it again above that' do
    add_lexicon_entry
    visit authority_path(author)

    expect(page).to have_css('.peach2-lexicon .by-card-v02')
    expect(page).to have_css('.sticky-fold', visible: :visible)

    scroll_to_lexicon

    expect(page).to have_css('.sticky-fold', visible: :hidden)

    page.execute_script('window.scrollTo(0, 0)')

    expect(page).to have_css('.sticky-fold', visible: :visible)
  end

  it 'keeps the bar up all the way down an authority page with no lexicon content' do
    visit authority_path(author)

    expect(page).to have_no_css('.peach2-lexicon')
    expect(page).to have_css('.sticky-fold', visible: :visible)

    page.execute_script('window.scrollTo(0, document.body.scrollHeight)')

    expect(page).to have_css('.sticky-fold', visible: :visible)
  end
end
