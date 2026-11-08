# frozen_string_literal: true

require 'rails_helper'

# Regression for GH #1779: pressing "Collapse all" from the middle of a long
# author page shrank everything above the viewport and left the reader at the
# bottom of the page. The collection the reader was looking at must stay in view.
describe 'Author TOC Collapse all keeps the scroll position', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  let!(:author) { create(:authority, name: 'Test Author') }

  let!(:volumes) do
    Chewy.strategy(:atomic) do
      (1..15).map do |i|
        volume = create(:collection, title: format('Volume %02d', i), collection_type: :volume)
        5.times do |j|
          work = create(:manifestation, title: "Work #{j} of volume #{i}", status: :published, author: author)
          create(:collection_item, collection: volume, item: work)
        end
        create(:involved_authority, authority: author, item: volume, role: 'editor')
        volume
      end
    end
  end

  after { Chewy.massacre }

  # Viewport-relative top of the given volume's title, and the action bar's bottom.
  def card_top(title)
    page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('#browse_mainlist .ctitle_only'))
           .find(function(el) { return el.textContent === #{title.to_json}; })
           .closest('.by-card-v02').getBoundingClientRect().top
    JS
  end

  it 'keeps the collection being read in view instead of jumping to the page bottom' do
    resize_window(1400, 600)
    visit authority_path(author)
    expect(page).to have_css('#browse_mainlist .volume-collapse-toggle', count: 15)

    # Scroll so a middle volume sits a bit below the top of the viewport.
    target = 'Volume 08'
    page.execute_script("window.scrollBy(0, #{card_top(target)} - 250)")
    expect(card_top(target)).to be_within(5).of(250)

    find('#max_collapse').click
    expect(page).to have_no_css('#browse_mainlist ul.toclist li.manifestation-node', visible: :visible, wait: 5)

    top = card_top(target)
    bar_bottom = page.evaluate_script("document.querySelector('.sticky-fold').getBoundingClientRect().bottom")
    expect(top).to be >= bar_bottom - 1
    expect(top).to be < page.evaluate_script('window.innerHeight')
  end
end
