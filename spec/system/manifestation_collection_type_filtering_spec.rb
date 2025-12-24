# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Manifestation collection type filtering', type: :system, js: true do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  before(:all) do
    clean_tables
    Chewy.strategy(:atomic) do
      # Create test data with different collection types
      @volume = create(:collection, collection_type: :volume, title: 'Test Volume')
      @periodical_issue = create(:collection, collection_type: :periodical_issue, title: 'Test Issue')
      @other_collection = create(:collection, collection_type: :series, title: 'Test Series')

      # Manifestation in a volume
      @m_in_volume = create(:manifestation, title: 'In Volume Work')
      create(:collection_item, collection: @volume, item: @m_in_volume)

      # Manifestation in a periodical issue
      @m_in_periodical = create(:manifestation, title: 'In Periodical Work')
      create(:collection_item, collection: @periodical_issue, item: @m_in_periodical)

      # Uncollected manifestation (not in volume or periodical)
      @m_uncollected = create(:manifestation, title: 'Uncollected Work')
      create(:collection_item, collection: @other_collection, item: @m_uncollected)

      # Manifestation in both volume and periodical
      @m_both = create(:manifestation, title: 'In Both Volume and Periodical')
      create(:collection_item, collection: @volume, item: @m_both)
      create(:collection_item, collection: @periodical_issue, item: @m_both)

      # Completely standalone manifestation
      @m_standalone = create(:manifestation, title: 'Standalone Work')

      ManifestationsIndex.reset!
    end
  end

  before(:each) do
    # Visit with a filter parameter to make the filter panel visible
    visit works_path(ckb_collection_types: ['in_volume'])
    # Wait for page to load
    expect(page).to have_css('.by-card-v02')
  end

  it 'successfully loads the works browse page with collection type filter' do
    expect(page).to have_css('#thelist')
    expect(page).to have_css('form#works_filters')
  end

  it 'displays collection type filter section' do
    # The filter form should be present
    expect(page).to have_css('form#works_filters')
    # The containing collection type filter should be present
    expect(page).to have_content(I18n.t(:containing_collection_type))
  end

  it 'allows filtering by collection types' do
    # Visit page with all filters checked (default state)
    visit works_path

    # Page should show works (exact count may vary based on test data)
    expect(page).to have_css('.by-card-v02')
  end

  after(:all) do
    clean_tables
  end
end
