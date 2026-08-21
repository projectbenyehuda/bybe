# frozen_string_literal: true

require 'rails_helper'

describe 'Periodical navbar prefix stripping' do
  let!(:author) { create(:authority) }

  describe 'periodical collection' do
    let!(:periodical) do
      create(:collection,
             title: 'My Periodical: A Magazine',
             collection_type: :periodical,
             authors: [author])
    end

    let!(:issue1) do
      create(:collection, title: 'My Periodical – Issue 1', collection_type: :periodical_issue)
    end

    let!(:issue2) do
      create(:collection, title: 'My Periodical – Issue 2', collection_type: :periodical_issue)
    end

    before do
      create(:collection_item, collection: periodical, item: issue1, seqno: 1)
      create(:collection_item, collection: periodical, item: issue2, seqno: 2)
    end

    it 'strips the periodical name prefix from sidebar nav items' do
      visit collection_path(periodical)

      within('#chapter-nav') do
        expect(page).to have_content('Issue 1')
        expect(page).to have_content('Issue 2')
        expect(page).not_to have_content('My Periodical – Issue 1')
        expect(page).not_to have_content('My Periodical – Issue 2')
      end
    end

    it 'strips the periodical name prefix from the chapters dropdown' do
      visit collection_path(periodical)

      options = all('#collitem_dropdown option').map(&:text)
      expect(options).to include('Issue 1', 'Issue 2')
      expect(options.join(' ')).not_to include('My Periodical')
    end
  end

  describe 'non-periodical collection' do
    let!(:volume) do
      create(:collection,
             title: 'A Volume',
             collection_type: :volume,
             authors: [author])
    end

    # Two manifestations prevent the single-item redirect in CollectionsController#show
    let!(:manifestation1) { create(:manifestation, title: 'Chapter One') }
    let!(:manifestation2) { create(:manifestation, title: 'Chapter Two') }

    before do
      create(:collection_item, collection: volume, item: manifestation1, seqno: 1)
      create(:collection_item, collection: volume, item: manifestation2, seqno: 2)
    end

    it 'leaves nav item titles unchanged' do
      visit collection_path(volume)

      within('#chapter-nav') do
        expect(page).to have_content('Chapter One')
        expect(page).to have_content('Chapter Two')
      end
    end
  end
end
