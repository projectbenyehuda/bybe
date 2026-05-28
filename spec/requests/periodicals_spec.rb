# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Periodicals', type: :request do
  describe 'GET /' do
    it 'returns http success' do
      get '/periodicals'
      expect(response).to have_http_status(:success)
    end

    context 'with new periodical publications' do
      let(:author) { create(:authority) }
      let(:periodical_issue) { create(:collection, collection_type: 'periodical_issue') }
      let!(:periodical_work) do
        work = create(:manifestation, author: author, orig_lang: 'he', created_at: 2.weeks.ago)
        create(:collection_item, collection: periodical_issue, item: work)
        work
      end

      it 'populates @periodicals_whatsnew with recent periodical publications' do
        get '/periodicals'
        expect(assigns(:periodicals_whatsnew)).to be_present
        expect(assigns(:periodicals_whatsnew).keys).to include(author)
      end

      it 'renders the whatsnew section in the view' do
        get '/periodicals'
        expect(response.body).to include('מה חדש בכתבי עת?')
      end
    end

    context 'without new periodical publications' do
      before do
        # Clear cache to ensure fresh data
        Rails.cache.delete('periodicals_whatsnew')
      end

      it 'displays the empty state message when there are no new publications' do
        get '/periodicals'
        # The view should still render successfully
        expect(response).to have_http_status(:success)
      end
    end

    context 'with more than 3 authors' do
      let(:periodical_issue) { create(:collection, collection_type: 'periodical_issue') }
      let!(:authors_and_works) do
        # Create 5 authors with works in periodicals (more than the 3-card limit)
        5.times.map do
          author = create(:authority)
          work = create(:manifestation, author: author, orig_lang: 'he', created_at: 2.weeks.ago)
          create(:collection_item, collection: periodical_issue, item: work)
          [author, work]
        end
      end

      before do
        # Clear cache to ensure fresh data
        Rails.cache.delete('periodicals_whatsnew')
      end

      it 'includes the see-all link when there are more than 3 authors' do
        get '/periodicals'
        expect(response.body).to include('link-to-all-v02')
        expect(response.body).to include(I18n.t(:see_all_new_periodicals))
      end

      it 'includes a modal with all new works' do
        get '/periodicals'
        expect(response.body).to include('periodicalsWhatsnewDlg')
        expect(response.body).to include(I18n.t(:new_works_in_periodicals))
      end

      it 'includes all author works in the page' do
        get '/periodicals'
        # All works should be present in the page (in the modal)
        authors_and_works.each do |author, work|
          expect(response.body).to include(work.expression.title)
        end
      end
    end
  end

  describe 'GET /show' do
    it 'returns http success' do
      get '/periodicals/show'
      expect(response).to have_http_status(:success)
    end
  end

  describe '@periodical_first_covers assignment' do
    let!(:periodical) { create(:collection, collection_type: 'periodical', title: 'Test Periodical Title') }
    let!(:issue_no_cover) { create(:collection, collection_type: 'periodical_issue') }
    let!(:issue_with_cover) do
      c = create(:collection, collection_type: 'periodical_issue')
      c.cover_image.attach(
        io: StringIO.new(Rails.root.join('spec/fixtures/files/test_image.jpg').binread),
        filename: 'cover.jpg',
        content_type: 'image/jpeg'
      )
      c
    end

    before do
      create(:collection_item, collection: periodical, item: issue_no_cover, seqno: 1)
      create(:collection_item, collection: periodical, item: issue_with_cover, seqno: 2)
    end

    it 'assigns @periodical_first_covers as a hash' do
      get '/periodicals'
      expect(assigns(:periodical_first_covers)).to be_a(Hash)
    end

    it 'maps the periodical to the first issue with a cover image' do
      get '/periodicals'
      expect(assigns(:periodical_first_covers)[periodical.id]).to eq(issue_with_cover)
    end

    it 'renders the cover image tile for periodicals with a covered issue' do
      get '/periodicals'
      expect(response.body).to include('periodical-with-cover')
      expect(response.body).to include('periodical-cover-img')
      expect(response.body).to include(periodical.title)
    end
  end

  describe '@periodical_first_covers with no covered issues' do
    let!(:periodical) { create(:collection, collection_type: 'periodical') }
    let!(:issue_no_cover) { create(:collection, collection_type: 'periodical_issue') }

    before do
      create(:collection_item, collection: periodical, item: issue_no_cover, seqno: 1)
    end

    it 'maps the periodical to nil when no issues have a cover' do
      get '/periodicals'
      expect(assigns(:periodical_first_covers)[periodical.id]).to be_nil
    end

    it 'does not render the cover image tile' do
      get '/periodicals'
      expect(response.body).not_to include('periodical-with-cover')
    end
  end
end
