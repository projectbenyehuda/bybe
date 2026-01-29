# frozen_string_literal: true

require 'rails_helper'

describe 'Tags browse view' do
  let!(:tag1) { create(:tag, name: 'Fiction', status: :approved) }
  let!(:tag2) { create(:tag, name: 'Poetry', status: :approved) }
  let!(:tag3) { create(:tag, name: 'Drama', status: :approved) }
  let!(:pending_tag) { create(:tag, name: 'Pending Tag', status: :pending) }

  before do
    # Create approved taggings to set the counter cache values
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

  describe 'show all functionality', :js do
    before do
      # Reduced from 30 to 26 - just enough to trigger pagination at 25 per page
      26.times do |i|
        create(:tag, name: "Tag#{i.to_s.rjust(3, '0')}", status: :approved)
      end
      visit tags_browse_path
    end

    it 'shows pagination by default when there are many tags' do
      expect(page).to have_css('.pagination-container')
    end

    it 'hides pagination when "show all" is checked' do
      check 'show_all_checkbox'
      # Use Capybara's built-in waiting instead of sleep
      expect(page).not_to have_css('.pagination-container', wait: 2)
    end

    it 'displays all tags when "show all" is checked' do
      check 'show_all_checkbox'

      # Should show all 29 tags (3 from setup + 26 created in before block)
      # Use Capybara's built-in waiting
      within('#tags_mainlist ol', wait: 2) do
        expect(page.all('li').count).to eq(29)
      end
    end

    it 'maintains the checkbox state when navigating with show_all param' do
      visit tags_browse_path(show_all: 'true')

      expect(page).to have_checked_field('show_all_checkbox')
      expect(page).not_to have_css('.pagination-container')
    end

    it 'shows pagination again when "show all" is unchecked' do
      visit tags_browse_path(show_all: 'true')
      uncheck 'show_all_checkbox'
      # Use Capybara's built-in waiting instead of sleep
      expect(page).to have_css('.pagination-container', wait: 2)
    end
  end
end
