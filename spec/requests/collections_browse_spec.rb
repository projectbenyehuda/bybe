# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Collections Browse', type: :request do
  after do
    Chewy.massacre
  end

  let!(:volume) { create(:collection, title: 'Test Volume', collection_type: :volume, sort_title: 'test volume') }
  let!(:series) { create(:collection, title: 'Test Series', collection_type: :series, sort_title: 'test series') }

  before do
    CollectionsIndex.import([volume, series])
  end

  describe 'GET /collections' do
    context 'HTML request' do
      it 'renders successfully' do
        get collections_browse_path
        expect(response).to have_http_status(:success)
      end

      it 'renders the browse template' do
        get collections_browse_path
        expect(response).to render_template(:browse)
      end

      it 'renders all required partials without HAML errors' do
        get collections_browse_path

        # Check that key elements from partials are present
        expect(response.body).to include('collections_filters') # from _browse_filters
        expect(response.body).to include(I18n.t(:collections_list)) # from _browse_top partial
        expect(response.body).to include('submit_filters') # JavaScript from browse.html.haml
      end

      it 'displays collection results' do
        get collections_browse_path
        expect(response.body).to include('Test Volume')
        expect(response.body).to include('Test Series')
      end

      it 'includes filter form elements' do
        get collections_browse_path

        # Check for key filter elements
        expect(response.body).to include('ckb_collection_types') # collection type checkboxes
        expect(response.body).to include('search_input') # title search
        expect(response.body).to include('fromdate') # date range
        expect(response.body).to include('todate')
      end

      it 'includes sorting controls' do
        get collections_browse_path
        expect(response.body).to include('sort_by_dd') # sort dropdown
      end
    end

    context 'JS/AJAX request' do
      it 'renders successfully' do
        get collections_browse_path, xhr: true, as: :js
        expect(response).to have_http_status(:success)
      end

      it 'returns JavaScript content' do
        get collections_browse_path, xhr: true, as: :js
        expect(response.content_type).to include('text/javascript')
      end

      it 'updates the list and filters' do
        get collections_browse_path, xhr: true, as: :js

        # Check that the JS updates the right elements
        expect(response.body).to include("$('#thelist')")
        expect(response.body).to include("$('#sort_filter_panel')")
        expect(response.body).to include('stopModal')
      end
    end

    context 'with filters applied' do
      it 'filters by collection type' do
        get collections_browse_path, params: { ckb_collection_types: ['volume'] }
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Test Volume')
      end

      it 'searches by title' do
        get collections_browse_path, params: { search_input: 'Volume' }
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Test Volume')
      end

      it 'applies sorting' do
        get collections_browse_path, params: { sort_by: 'alphabetical_asc' }
        expect(response).to have_http_status(:success)
      end
    end

    context 'edge cases' do
      it 'handles invalid to_letter parameter' do
        get collections_browse_path, params: { to_letter: 'invalid' }
        expect(response).to have_http_status(:bad_request)
      end

      it 'handles empty result set gracefully' do
        get collections_browse_path, params: { search_input: 'nonexistent' }
        expect(response).to have_http_status(:success)
      end
    end
  end
end
