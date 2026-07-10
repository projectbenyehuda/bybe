# frozen_string_literal: true

require 'rails_helper'

# Alphabetical Collections sort ('colls_abc') on the Authority TOC. Unlike the
# flat manifestation-level sorts, it must keep the chronological
# one-card-per-collection layout (a card per collection, not a single card
# containing everything) and only reorder the collection cards by title.
# Uncollected works keep their own trailing section (they must not jump to the top).
describe 'Author TOC alphabetical Collections sort', :js do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  let!(:author) { create(:authority, name: 'ABC Sort Author') }

  # Two work-level collections whose alphabetical order (Apple, Zebra) is the
  # reverse of their chronological order (Zebra is created first, so it has the
  # lower id and sorts first by sort_term = [pub_year, id]).
  let!(:zebra) { create(:collection, title: 'Zebra Collection', collection_type: :volume) }
  let!(:apple) { create(:collection, title: 'Apple Collection', collection_type: :volume) }

  before do
    Chewy.strategy(:atomic) do
      zwork = create(:manifestation, title: 'Z Work', status: :published, author: author,
                                     genre: 'poetry', orig_lang: 'he', language: 'he')
      awork = create(:manifestation, title: 'A Work', status: :published, author: author,
                                     genre: 'poetry', orig_lang: 'he', language: 'he')
      # A standalone work by the author, in no collection -> lands in "uncollected".
      create(:manifestation, title: 'Solo Uncollected Work', status: :published, author: author,
                             genre: 'poetry', orig_lang: 'he', language: 'he')
      create(:collection_item, collection: zebra, item: zwork)
      create(:collection_item, collection: apple, item: awork)
    end
    RefreshUncollectedWorksCollection.call(author)
  end

  after { Chewy.massacre }

  def choose_sort(value)
    find("#sort_by option[value='#{value}']").select_option
  end

  # Layout-independent DOM order: -1 if a precedes b, 1 otherwise.
  def dom_order(sel_a, sel_b)
    page.evaluate_script(<<~JS)
      (function(){
        var a = document.querySelector(#{sel_a.to_json});
        var b = document.querySelector(#{sel_b.to_json});
        if(!a || !b) { return 0; }
        return (a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING) ? -1 : 1;
      })()
    JS
  end

  let(:apple_sel) { "#browse_mainlist .cwrapper[data-collection-id='#{apple.id}']" }
  let(:zebra_sel) { "#browse_mainlist .cwrapper[data-collection-id='#{zebra.id}']" }
  let(:uncollected_sel) { '#browse_mainlist .cwrapper.uncollected' }

  it 'reorders collection cards alphabetically while keeping one card per collection' do
    visit authority_path(author)
    expect(page).to have_css('#browse_mainlist')
    expect(page).to have_css(apple_sel, visible: :all)
    expect(page).to have_css(zebra_sel, visible: :all)

    # Default chronological sort: Zebra (older/lower id) precedes Apple.
    expect(dom_order(zebra_sel, apple_sel)).to eq(-1)

    choose_sort('colls_abc')

    # Still one card per collection -- NOT a single #sorted_card mega-card.
    expect(page).to have_no_css('#sorted_card')
    expect(page).to have_css("#browse_mainlist .by-card-v02[role='treeitem']", minimum: 2)

    # Now alphabetical: Apple precedes Zebra.
    expect(dom_order(apple_sel, zebra_sel)).to eq(-1)
  end

  it 'keeps the uncollected works at the very end, not the beginning' do
    visit authority_path(author)
    expect(page).to have_css(uncollected_sel, visible: :all)

    choose_sort('colls_abc')

    # The uncollected section comes after both named collections.
    expect(dom_order(apple_sel, uncollected_sel)).to eq(-1)
    expect(dom_order(zebra_sel, uncollected_sel)).to eq(-1)
  end
end
