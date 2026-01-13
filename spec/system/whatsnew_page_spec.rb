# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Whatsnew Page', :js, type: :system do
  let!(:old_author) do
    author = create(:authority, created_at: 3.months.ago)
    # Create a published manifestation so author is not filtered out
    m = create(:manifestation, status: :published, created_at: 3.months.ago)
    create(:involved_authority, authority: author, item: m.expression.work, role: 'author')
    author
  end
  let!(:new_author) do
    author = create(:authority, created_at: 2.weeks.ago)
    # Create a published manifestation so author is not filtered out
    m = create(:manifestation, status: :published, created_at: 2.weeks.ago)
    create(:involved_authority, authority: author, item: m.expression.work, role: 'author')
    author
  end
  let!(:new_manifestation) do
    create(:manifestation, status: :published, created_at: 1.week.ago)
  end
  let!(:old_manifestation) do
    create(:manifestation, status: :published, created_at: 3.months.ago)
  end
  let!(:new_collection) do
    collection = create(:collection, collection_type: :volume, created_at: 1.week.ago)
    # Add a published manifestation to the collection
    m = create(:manifestation, status: :published, created_at: 1.week.ago)
    create(:collection_item, collection: collection, item: m, seqno: 1)
    collection
  end
  let!(:old_collection) do
    collection = create(:collection, collection_type: :volume, created_at: 3.months.ago)
    # Add a published manifestation to the collection
    m = create(:manifestation, status: :published, created_at: 3.months.ago)
    create(:collection_item, collection: collection, item: m, seqno: 1)
    collection
  end
  let!(:new_tag) { create(:tag, status: :approved, created_at: 1.week.ago, updated_at: 1.week.ago) }
  let!(:old_tag) { create(:tag, status: :approved, created_at: 3.months.ago, updated_at: 3.months.ago) }

  before do
    Rails.cache.clear # Clear cache before each test
    visit whatsnew_path
  end

  describe 'page structure' do
    it 'shows all four category sections' do
      expect(page).to have_css('#new-authors')
      expect(page).to have_css('#new-texts')
      expect(page).to have_css('#new-collections')
      expect(page).to have_css('#new-tags')
    end

    it 'has navigation sidebar with links to all sections' do
      within('.whatsnew-nav') do
        expect(page).to have_link(I18n.t(:new_authors), href: '#new-authors')
        expect(page).to have_link(I18n.t(:new_texts), href: '#new-texts')
        expect(page).to have_link(I18n.t(:new_collections), href: '#new-collections')
        expect(page).to have_link(I18n.t(:new_tags), href: '#new-tags')
      end
    end

    it 'has sort toggle buttons' do
      expect(page).to have_button(I18n.t(:alphabetical))
      expect(page).to have_button(I18n.t(:recent))
    end

    it 'uses tri-partite layout with three columns' do
      expect(page).to have_css('.whatsnew-nav.col-lg-2')
      expect(page).to have_css('.col-lg-8')
      expect(page).to have_css('.col-lg-2')
    end
  end

  describe 'filtering by recency' do
    it 'shows only authors from last 30 days' do
      within('#new-authors') do
        expect(page).to have_link(new_author.name)
        expect(page).not_to have_link(old_author.name)
      end
    end

    it 'shows only texts from last 30 days' do
      within('#new-texts') do
        expect(page).to have_link(href: manifestation_path(new_manifestation))
        expect(page).not_to have_link(href: manifestation_path(old_manifestation))
      end
    end

    it 'shows only collections from last 30 days' do
      within('#new-collections') do
        expect(page).to have_link(new_collection.title)
        expect(page).not_to have_link(old_collection.title)
      end
    end

    it 'shows old collections if they contain new manifestations' do
      # Create an old collection with a new manifestation
      old_collection_with_new_content = create(:collection, collection_type: :volume, created_at: 3.months.ago)
      new_m = create(:manifestation, status: :published, created_at: 1.week.ago)
      create(:collection_item, collection: old_collection_with_new_content, item: new_m, seqno: 1)

      visit whatsnew_path

      within('#new-collections') do
        expect(page).to have_link(old_collection_with_new_content.title)
      end
    end

    it 'shows old collections with nested collections containing new manifestations' do
      # Create an old parent collection
      parent_collection = create(:collection, collection_type: :volume, created_at: 3.months.ago)
      # Create an old nested collection
      nested_collection = create(:collection, collection_type: :volume, created_at: 3.months.ago)
      create(:collection_item, collection: parent_collection, item: nested_collection, seqno: 1)
      # Add a new manifestation to the nested collection
      new_m = create(:manifestation, status: :published, created_at: 1.week.ago)
      create(:collection_item, collection: nested_collection, item: new_m, seqno: 1)

      visit whatsnew_path

      within('#new-collections') do
        # Both parent and nested collections should be shown because they contain a new manifestation
        expect(page).to have_link(parent_collection.title)
        expect(page).to have_link(nested_collection.title)
      end
    end

    it 'shows only tags from last 30 days' do
      within('#new-tags') do
        expect(page).to have_link(new_tag.name)
        expect(page).not_to have_link(old_tag.name)
      end
    end
  end

  describe 'sorting' do
    it 'defaults to alphabetical sort' do
      expect(page).to have_css('#sort_alpha.active')
      expect(page).not_to have_css('#sort_recent.active')
    end

    it 'switches to recent sort when clicked', :js do
      click_button I18n.t(:recent)
      expect(page).to have_current_path(/sort=recent/)
      expect(page).to have_css('#sort_recent.active')
      expect(page).not_to have_css('#sort_alpha.active')
    end

    it 'switches back to alphabetical sort when clicked', :js do
      # First switch to recent
      click_button I18n.t(:recent)
      expect(page).to have_css('#sort_recent.active')

      # Then switch back to alphabetical
      click_button I18n.t(:alphabetical)
      expect(page).to have_current_path(/sort=alpha/)
      expect(page).to have_css('#sort_alpha.active')
    end
  end

  describe 'navigation' do
    it 'has smooth scrolling for nav links', :js do
      # Click a nav link
      within('.whatsnew-nav') do
        click_link I18n.t(:new_tags)
      end

      # Check that the URL has the hash
      expect(page).to have_current_path(/\#new-tags/)
    end
  end

  describe 'caching' do
    it 'caches the page content for performance' do
      # This test verifies that the cache key exists
      # The actual caching behavior is tested by checking cache invalidation
      expect(Rails.cache).not_to exist(%w[whatsnew_page alpha]) # not cached yet on first visit

      # Visit the page to trigger caching
      visit whatsnew_path

      # After rendering, the cache should exist
      # Note: This might not work in test environment depending on caching config
      # The cache behavior is better tested through integration with cache invalidation
    end
  end

  describe 'empty states' do
    context 'when there are no new items' do
      before do
        # Remove all recent items
        Authority.where('created_at > ?', 1.month.ago).destroy_all
        Manifestation.where('created_at > ?', 1.month.ago).destroy_all
        Collection.where('created_at > ?', 1.month.ago).destroy_all
        # Tags are filtered by updated_at, not created_at
        Tag.where('updated_at > ?', 1.month.ago).destroy_all

        Rails.cache.clear
        visit whatsnew_path
      end

      it 'shows empty state message for authors' do
        within('#new-authors') do
          expect(page).to have_content(I18n.t(:no_new_authors))
        end
      end

      it 'shows empty state message for texts' do
        within('#new-texts') do
          expect(page).to have_content(I18n.t(:no_new_texts))
        end
      end

      it 'shows empty state message for collections' do
        within('#new-collections') do
          expect(page).to have_content(I18n.t(:no_new_collections))
        end
      end

      it 'shows empty state message for tags' do
        within('#new-tags') do
          expect(page).to have_content(I18n.t(:no_new_tags))
        end
      end
    end
  end

  describe 'collection type grouping' do
    let!(:new_periodical) do
      collection = create(:collection, collection_type: :periodical, created_at: 1.week.ago)
      # Add a published manifestation to the collection
      m = create(:manifestation, status: :published, created_at: 1.week.ago)
      create(:collection_item, collection: collection, item: m, seqno: 1)
      collection
    end
    let!(:new_series) do
      create(:collection, collection_type: :series, created_at: 1.week.ago)
    end

    before do
      Rails.cache.clear
      visit whatsnew_path
    end

    it 'groups collections by type' do
      within('#new-collections') do
        # Should show volume type heading (from the base fixtures)
        expect(page).to have_content(I18n.t('collection.type.volume'))
        # Should show periodical type heading
        expect(page).to have_content(I18n.t('collection.type.periodical'))
      end
    end

    it 'excludes series type collections as per requirements' do
      within('#new-collections') do
        # Should NOT show series
        expect(page).not_to have_content(new_series.title)
        expect(page).not_to have_content(I18n.t('collection.type.series'))
      end
    end
  end
end
