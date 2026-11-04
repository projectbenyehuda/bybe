# frozen_string_literal: true

require 'rails_helper'

# On mobile the periodical title and stats used to overlay the cover image (and long titles were
# cut off). They now sit below the cover. Desktop keeps the overlay.
describe 'Periodicals index cover tiles', :js, :narrow_viewport, type: :system do
  let!(:periodical) { create(:collection, collection_type: :periodical, title: 'Long Periodical Title') }

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?

    issue = create(:collection, collection_type: :periodical_issue)
    issue.cover_image.attach(
      io: StringIO.new(Rails.root.join('spec/fixtures/files/test_image.jpg').binread),
      filename: 'cover.jpg',
      content_type: 'image/jpeg'
    )
    create(:collection_item, collection: issue, seqno: 1, item: create(:manifestation, status: :published))
    create(:collection_item, collection: periodical, item: issue, seqno: 1)
  end

  def tile_geometry
    page.evaluate_script(<<~JS)
      (function() {
        var img = document.querySelector('.periodical-with-cover .periodical-cover-img').getBoundingClientRect();
        var name = document.querySelector('.periodical-with-cover .author-name-area').getBoundingClientRect();
        return { imgBottom: img.bottom, nameTop: name.top };
      })()
    JS
  end

  it 'places the title and stats below the cover on mobile' do
    resize_window(390, 844)
    visit periodicals_path
    expect(page).to have_css('.periodical-with-cover .author-name-area', text: 'Long Periodical Title')
    geometry = tile_geometry
    expect(geometry['nameTop']).to be >= geometry['imgBottom']
  end

  it 'overlays the title and stats on the cover on desktop' do
    resize_window(1400, 900)
    visit periodicals_path
    expect(page).to have_css('.periodical-with-cover .author-name-area', text: 'Long Periodical Title')
    geometry = tile_geometry
    expect(geometry['nameTop']).to be < geometry['imgBottom']
  end
end
