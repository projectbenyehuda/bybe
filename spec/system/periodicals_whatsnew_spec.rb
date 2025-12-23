# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Periodicals whatsnew panel', type: :system, js: true do
  let(:periodical_issue) { create(:collection, collection_type: 'periodical_issue', title: 'Test Periodical Issue') }

  before do
    # Clear cache to ensure fresh data
    Rails.cache.delete('periodicals_whatsnew')
  end

  context 'with few works (no overflow)' do
    let!(:author) { create(:authority) }
    let!(:work) do
      work = create(:manifestation, author: author, orig_lang: 'he', created_at: 2.weeks.ago)
      create(:collection_item, collection: periodical_issue, item: work)
      work
    end

    it 'displays the work without showing the see-all link' do
      visit '/periodicals'

      within '#whats-new-bg' do
        expect(page).to have_content(author.name)
        expect(page).to have_content(work.expression.title)
        # The see-all link should not be visible when there's no overflow
        expect(page).not_to have_css('.link-to-all-v02', visible: true)
      end
    end
  end

  context 'with more than 3 authors (expect see-all link)' do
    let!(:authors_with_works) do
      # Create 5 authors to exceed the 3-card limit
      5.times.map do
        author = create(:authority)
        works = 2.times.map do
          work = create(:manifestation, author: author, orig_lang: 'he', created_at: 2.weeks.ago)
          create(:collection_item, collection: periodical_issue, item: work)
          work
        end
        [author, works]
      end
    end

    it 'displays exactly 3 cards and shows the see-all link' do
      visit '/periodicals'

      within '#whats-new-bg' do
        # Should render exactly 3 cards
        cards = page.all('.new-card-v02', wait: 5)
        expect(cards.count).to eq(3)

        # The see-all link should be visible
        expect(page).to have_css('.link-to-all-v02', visible: true)
        expect(page).to have_content(I18n.t(:see_all_new_periodicals))
      end
    end

    it 'shows all 5 authors in the modal when clicking see-all link' do
      visit '/periodicals'

      within '#whats-new-bg' do
        # Click the see-all link
        find('.link-to-all-v02 a').click
      end

      # Modal should appear
      within '#periodicalsWhatsnewDlg', visible: true, wait: 5 do
        expect(page).to have_content(I18n.t(:new_works_in_periodicals))

        # All 5 authors and their works should be in the modal
        authors_with_works.each do |author, works|
          expect(page).to have_content(author.name)
          works.each do |work|
            expect(page).to have_content(work.expression.title)
          end
        end
      end
    end
  end
end
