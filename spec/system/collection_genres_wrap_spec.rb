# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/DescribeClass
describe 'Collection show page - genres summary on mobile', :js do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  let!(:collection) do
    Chewy.strategy(:atomic) do
      manifestations = Work::GENRES.first(6).map do |genre|
        create(:manifestation, genre: genre, markdown: 'Content', status: :published)
      end
      create(:collection, collection_type: :volume, manifestations: manifestations)
    end
  end

  after do
    Chewy.massacre
  end

  it 'keeps every genre within the viewport width' do
    resize_window(390, 844)
    visit collection_path(collection)

    expect(page).to have_css('.collection-genres > div', count: 6, wait: 10)
    heights = page.all('.collection-genres > div').map do |genre|
      page.evaluate_script('arguments[0].getBoundingClientRect().height', genre.native)
    end

    # genres wrap as whole items; a squeezed genre would wrap its own label onto a second line
    expect(heights.max - heights.min).to be < 2
  end
end
# rubocop:enable RSpec/DescribeClass
