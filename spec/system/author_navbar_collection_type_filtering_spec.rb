# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Author navbar collection type filtering', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  let!(:author) { create(:authority, name: 'Test Author') }

  after { Chewy.massacre }

  describe 'sidebar collection type filtering' do
    context 'when author has a volume collection at collection level' do
      let!(:volume_collection) { create(:collection, title: 'A Volume', collection_type: :volume) }
      let!(:involvement) { create(:involved_authority, authority: author, item: volume_collection, role: 'author') }

      before do
        Chewy.strategy(:atomic) do
          m = create(:manifestation, title: 'Volume Work', status: :published)
          create(:collection_item, collection: volume_collection, item: m)
        end
      end

      it 'shows the collection-level section in the sidebar' do
        visit authority_path(author)
        expect(page).to have_css('.book-nav-full')
        within('.book-nav-full') do
          expect(page).to have_css('#collection-author-collapse', visible: :all)
        end
      end
    end

    context 'when author has a volume_series collection at collection level' do
      let!(:vs_collection) { create(:collection, title: 'A Volume Series', collection_type: :volume_series) }
      let!(:involvement) { create(:involved_authority, authority: author, item: vs_collection, role: 'author') }

      before do
        Chewy.strategy(:atomic) do
          m = create(:manifestation, title: 'Volume Series Work', status: :published)
          create(:collection_item, collection: vs_collection, item: m)
        end
      end

      it 'shows the collection-level section in the sidebar' do
        visit authority_path(author)
        expect(page).to have_css('.book-nav-full')
        within('.book-nav-full') do
          expect(page).to have_css('#collection-author-collapse', visible: :all)
        end
      end
    end

    context 'when author has only a series-type collection at collection level' do
      let!(:series_collection) { create(:collection, title: 'A Series', collection_type: :series) }
      let!(:involvement) { create(:involved_authority, authority: author, item: series_collection, role: 'author') }

      before do
        Chewy.strategy(:atomic) do
          m = create(:manifestation, title: 'Series Work', status: :published)
          create(:collection_item, collection: series_collection, item: m)
        end
      end

      it 'does not show the collection-level section in the sidebar' do
        visit authority_path(author)
        expect(page).to have_css('.book-nav-full')
        within('.book-nav-full') do
          expect(page).not_to have_css('#collection-author-collapse', visible: :all)
        end
      end
    end

    context 'when author has only an other-type collection at collection level' do
      let!(:other_collection) { create(:collection, title: 'Other', collection_type: :other) }
      let!(:involvement) { create(:involved_authority, authority: author, item: other_collection, role: 'author') }

      before do
        Chewy.strategy(:atomic) do
          m = create(:manifestation, title: 'Other Work', status: :published)
          create(:collection_item, collection: other_collection, item: m)
        end
      end

      it 'does not show the collection-level section in the sidebar' do
        visit authority_path(author)
        expect(page).to have_css('.book-nav-full')
        within('.book-nav-full') do
          expect(page).not_to have_css('#collection-author-collapse', visible: :all)
        end
      end
    end
  end

  describe 'nested collection rendering' do
    let!(:volume_series) { create(:collection, title: 'Test Volume Series', collection_type: :volume_series) }
    let!(:nested_volume) { create(:collection, title: 'Nested Volume', collection_type: :volume) }
    let!(:nested_series) { create(:collection, title: 'Nested Series', collection_type: :series) }

    before do
      create(:involved_authority, authority: author, item: volume_series, role: 'author')
      create(:collection_item, collection: volume_series, item: nested_volume)
      create(:collection_item, collection: volume_series, item: nested_series)
      Chewy.strategy(:atomic) do
        vol_work = create(:manifestation, title: 'Volume Work', status: :published)
        create(:collection_item, collection: nested_volume, item: vol_work)
        series_work = create(:manifestation, title: 'Series Work', status: :published)
        create(:collection_item, collection: nested_series, item: series_work)
      end
    end

    it 'shows a nested allowed collection (volume) within volume_series in the sidebar' do
      visit authority_path(author)
      expect(page).to have_css('.book-nav-full')
      within('.book-nav-full') do
        expect(page).to have_css('.collection-anchor-link', text: 'Nested Volume', visible: :all)
      end
    end

    it 'does not show a nested non-allowed collection (series) within volume_series in the sidebar' do
      visit authority_path(author)
      expect(page).to have_css('.book-nav-full')
      within('.book-nav-full') do
        expect(page).not_to have_content('Nested Series')
      end
    end
  end

  describe 'uncollected works section' do
    before do
      Chewy.strategy(:atomic) do
        create(:manifestation, title: 'Uncollected Work', status: :published, author: author)
      end
    end

    it 'is not collapsible' do
      visit authority_path(author)
      expect(page).to have_css('.book-nav-full')
      within('.book-nav-full') do
        uncollected_truncate = find(".truncate[data-scroll-target='#works-author-uncollected']",
                                    visible: :all)
        expect(uncollected_truncate['data-bs-toggle']).to be_nil
      end
    end

    it 'always shows uncollected works without requiring expansion' do
      visit authority_path(author)
      expect(page).to have_css('.book-nav-full')
      within('.book-nav-full') do
        # The uncollected list should be a plain navbar-nav, not a Bootstrap collapse element
        expect(page).not_to have_css("ul.collapse.navbar-nav[id*='uncollected']", visible: :all)
        expect(page).to have_css('ul.navbar-nav', visible: true)
      end
    end
  end
end
