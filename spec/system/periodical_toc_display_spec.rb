# frozen_string_literal: true

require 'rails_helper'

# Covers two display tweaks for the periodical Collection#show table-of-contents
# (rendered by Collection#toc_html into a .collection_toc block):
#   1. the <ul> has no bullets (list-style: none)
#   2. rows for `series` sub-collections are plain text, not links (series are
#      groupings, not standalone browsable pages), while their nested items stay linked.
RSpec.describe 'Periodical Collection#show TOC display', :js, type: :system do
  # Two manifestations so the periodical isn't collapsed by the single-manifestation
  # redirect in CollectionsController#show.
  let!(:poem_a) do
    Chewy.strategy(:atomic) { create(:manifestation, title: 'First poem in series', status: :published) }
  end
  let!(:poem_b) do
    Chewy.strategy(:atomic) { create(:manifestation, title: 'Second poem in series', status: :published) }
  end

  # periodical -> periodical_issue -> series -> [poem_a, poem_b]
  let!(:series) { create(:collection, title: 'A poem cycle', collection_type: :series) }
  let!(:issue) { create(:collection, title: 'Issue 1', collection_type: :periodical_issue) }
  let!(:periodical) { create(:collection, title: 'Test Periodical', collection_type: :periodical) }

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?

    create(:collection_item, collection: series, item: poem_a, seqno: 1)
    create(:collection_item, collection: series, item: poem_b, seqno: 2)
    create(:collection_item, collection: issue, item: series, seqno: 1)
    create(:collection_item, collection: periodical, item: issue, seqno: 1)
  end

  after { Chewy.massacre }

  it 'renders the TOC list without bullets' do
    visit collection_path(periodical)

    expect(page).to have_css('.collection_toc ul', wait: 10)

    list_style = page.evaluate_script(<<~JS)
      window.getComputedStyle(document.querySelector('.collection_toc ul')).listStyleType
    JS

    expect(list_style).to eq('none')
  end

  it 'shows the series sub-collection as plain text while keeping its items linked' do
    visit collection_path(periodical)

    expect(page).to have_css('.collection_toc', wait: 10)

    # The series grouping title appears, but not as a link...
    within('.collection_toc') do
      expect(page).to have_text('A poem cycle')
      expect(page).not_to have_link('A poem cycle')
      # ...while the nested manifestations remain clickable.
      expect(page).to have_link(text: /First poem in series/)
      expect(page).to have_link(text: /Second poem in series/)
    end
  end
end
