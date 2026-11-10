# frozen_string_literal: true

require 'rails_helper'

# Regression spec for GH #1777: hovering a wrapped item in the collection's main-area table of contents
# collapsed it into a single clipped line and gave it a white background.
# rubocop:disable RSpec/DescribeClass
describe 'Collection show page - table of contents hover', :js do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  let(:long_title) { 'חליפת מכתבים ארוכה מאוד בין משורר ידוע לעורך כתב עת ספרותי ' * 4 }

  let!(:collection) do
    Chewy.strategy(:atomic) do
      # two items, since a single-item collection redirects to its manifestation
      manifestations = [long_title.strip, 'קצר'].map do |title|
        create(:manifestation, title: title, markdown: 'Content', status: :published)
      end
      create(:collection, collection_type: :volume, manifestations: manifestations)
    end
  end

  after do
    Chewy.massacre
  end

  def item_height(item)
    page.evaluate_script('arguments[0].getBoundingClientRect().height', item.native)
  end

  it 'keeps a wrapped item wrapped and uses the violet hover background' do
    resize_window(1200, 900)
    visit collection_path(collection)

    item = find('.binder-texts-list a.side-menu-item', text: 'חליפת', wait: 10)
    line_height = page.evaluate_script('parseFloat(getComputedStyle(arguments[0]).lineHeight)', item.native)
    height_before = item_height(item)
    expect(height_before).to be > line_height * 1.5 # sanity check: the title actually wraps

    item.hover
    expect(page).to have_css('.binder-texts-list a.side-menu-item:hover')

    expect(item_height(item)).to be_within(1).of(height_before)
    expect(item.native.style('background-color')).to eq('rgb(217, 205, 213)') # #d9cdd5, site-wide a:hover
  end
end
# rubocop:enable RSpec/DescribeClass
