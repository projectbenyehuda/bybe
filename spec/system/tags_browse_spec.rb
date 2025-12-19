# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Tags browse view', type: :system, js: true do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  let!(:tag1) { create(:tag, name: 'Fiction', status: :approved, taggings_count: 5) }
  let!(:tag2) { create(:tag, name: 'Poetry', status: :approved, taggings_count: 10) }
  let!(:tag3) { create(:tag, name: 'Drama', status: :approved, taggings_count: 3) }
  let!(:pending_tag) { create(:tag, name: 'Pending Tag', status: :pending) }

  # Create some approved taggings for the tags
  let!(:manifestation1) { create(:manifestation) }
  let!(:manifestation2) { create(:manifestation) }
  let!(:manifestation3) { create(:manifestation) }

  before do
    # Create approved taggings to match the counts
    5.times { create(:tagging, tag: tag1, status: :approved, taggable: create(:manifestation)) }
    10.times { create(:tagging, tag: tag2, status: :approved, taggable: create(:manifestation)) }
    3.times { create(:tagging, tag: tag3, status: :approved, taggable: create(:manifestation)) }

    visit tags_browse_path
  end

  describe 'viewing tags list' do
    it 'displays the page title' do
      expect(page).to have_content(I18n.t(:tags_list))
    end

    it 'shows total count of approved tags' do
      expect(page).to have_content('(3)')
    end

    it 'displays approved tags with their names' do
      expect(page).to have_link('Fiction')
      expect(page).to have_link('Poetry')
      expect(page).to have_link('Drama')
    end

    it 'does not display pending tags' do
      expect(page).not_to have_content('Pending Tag')
    end

    it 'shows approved taggings count for each tag' do
      within('#tags_mainlist') do
        expect(page).to have_content('(5)') # Fiction
        expect(page).to have_content('(10)') # Poetry
        expect(page).to have_content('(3)') # Drama
      end
    end

    it 'links tags to their portal pages' do
      expect(page).to have_link('Fiction', href: tag_path(tag1.id))
      expect(page).to have_link('Poetry', href: tag_path(tag2.id))
      expect(page).to have_link('Drama', href: tag_path(tag3.id))
    end
  end

  describe 'sorting' do
    it 'defaults to alphabetical sorting' do
      within('#tags_mainlist ol') do
        items = page.all('li').map(&:text)
        expect(items[0]).to include('Drama')
        expect(items[1]).to include('Fiction')
        expect(items[2]).to include('Poetry')
      end
    end

    it 'allows sorting by popularity', :js do
      select I18n.t(:by_popularity), from: 'sort_by_select'
      sleep 1 # Wait for page reload

      within('#tags_mainlist ol') do
        items = page.all('li').map(&:text)
        expect(items[0]).to include('Poetry') # 10 taggings
        expect(items[1]).to include('Fiction') # 5 taggings
        expect(items[2]).to include('Drama') # 3 taggings
      end
    end
  end
end
