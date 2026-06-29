# frozen_string_literal: true

require 'rails_helper'

describe 'Author navbar conditional expand and bottom collapse button', :js do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  let!(:author) { create(:authority, name: 'Test Author') }
  let!(:volume_collection) { create(:collection, collection_type: :volume) }

  after { Chewy.massacre }

  def create_manifestations(count)
    Chewy.strategy(:atomic) do
      create_list(:manifestation, count, status: :published, author: author,
                  collections: [volume_collection])
    end
  end

  describe 'initial expand/collapse state' do
    context 'when total works is at or below MAX_EXPANDED_WORKS (20)' do
      before { create_manifestations(5) }

      it 'starts with sections expanded' do
        visit authority_path(author)
        expect(page).to have_css('.collapse.navbar-nav.show', wait: 5)
      end
    end

    context 'when total works exceeds MAX_EXPANDED_WORKS (20)' do
      before { create_manifestations(21) }

      it 'starts with all sections collapsed' do
        visit authority_path(author)
        expect(page).to have_no_css('.collapse.navbar-nav.show', wait: 5)
        expect(page).to have_css('.collapse.navbar-nav', visible: false, wait: 5)
      end
    end
  end

  describe 'bottom section collapse button' do
    before { create_manifestations(3) }

    it 'is present at the bottom of each expanded section' do
      visit authority_path(author)
      expect(page).to have_css('.section-collapse-btn', wait: 5)
    end

    it 'collapses the section when clicked' do
      visit authority_path(author)

      # Confirm section is initially expanded
      expect(page).to have_css('.collapse.navbar-nav.show', wait: 5)

      # Click the bottom collapse button
      first('.section-collapse-link').click

      # The section should now be collapsed (no longer has .show)
      expect(page).to have_css('.collapse.navbar-nav:not(.show)', visible: false, wait: 5)
    end
  end
end
