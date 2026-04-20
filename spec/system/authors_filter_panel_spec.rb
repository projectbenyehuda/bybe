# frozen_string_literal: true

require 'rails_helper'

describe 'Authors filter panel behavior' do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?

    Chewy.strategy(:atomic) do
      create(:manifestation, author: create(:authority, gender: 'female'))
      create(:manifestation, author: create(:authority, gender: 'male'))
      create(:manifestation, author: create(:authority, gender: 'male', period: 'modern'))
    end
  end

  after do
    Chewy.massacre
  end

  context 'when no filters are applied' do
    it 'shows the filter panel by default' do
      visit authors_path

      expect(page).to have_css('#sort_filter_panel', visible: :visible)
      expect(page).not_to have_css('#browse_intro')
      expect(page).not_to have_css('#sort_filter_toggle')
    end
  end

  context 'when a filter is applied', :js do
    it 'filter panel remains visible after applying a filter', :aggregate_failures do
      visit authors_path

      expect(page).to have_css('#sort_filter_panel', visible: :visible)

      find('#gender_female', visible: :visible).click

      expect(page).to have_css('.tag', text: 'יוצר: נקבה', wait: 5)

      expect(find('#sort_filter_panel', visible: :all)).to be_visible
    end
  end

  context 'when filters are reset', :js do
    it 'filter panel remains visible after resetting filters', :aggregate_failures do
      visit authors_path

      find('#gender_female', visible: :visible).click

      expect(page).to have_css('.tag', text: 'יוצר: נקבה', wait: 5)

      find('.reset', visible: :visible).click

      expect(page).not_to have_css('.tag', text: 'יוצר: נקבה', wait: 5)

      expect(find('#sort_filter_panel', visible: :all)).to be_visible
    end
  end
end
