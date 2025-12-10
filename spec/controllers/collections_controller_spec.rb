# frozen_string_literal: true

require 'rails_helper'

describe CollectionsController do
  let(:collection) do
    create(
      :collection,
      manifestations: create_list(:manifestation, 3),
      included_collections: create_list(:collection, 2)
    )
  end

  describe '#show' do
    subject! { get :show, params: { id: collection.id } }

    it { is_expected.to be_successful }

    context 'when collection and subcollections contains a single manifestation' do
      let(:manifestation) { create(:manifestation) }

      let(:subcollection) do
        create(:collection, manifestations: [manifestation])
      end

      let(:collection) do
        create(:collection, included_collections: [subcollection])
      end

      it { is_expected.to redirect_to manifestation_path(manifestation) }
    end

    context 'when collection is not periodical' do
      let(:collection_type) { (Collection.collection_types.keys - %w(periodical volume_series) - Collection::SYSTEM_TYPES).sample }

      context 'when collection contains several manifestations' do
        let(:collection) do
          create(
            :collection,
            collection_type: collection_type,
            manifestations: create_list(:manifestation, 2)
          )
        end

        it 'marks manifestation divs as proofable' do
          expect(response.body).to have_css('.by-card-v02.proofable', count: 2)
          collection.collection_items.each do |ci|
            expect(response.body).to have_css(
              ".proofable[data-item-id='#{ci.item_id}'][data-item-type='Manifestation']"
            )
          end
        end
      end

      context 'when collection contains nested collections with manifestations' do
        let(:nested_manifestation) { create(:manifestation, title: 'Nested Manifestation') }
        let(:nested_collection) do
          create(:collection, title: 'Nested Collection', manifestations: [nested_manifestation])
        end
        let(:collection) do
          create(
            :collection,
            collection_type: collection_type,
            included_collections: [nested_collection],
            manifestations: [create(:manifestation)]
          )
        end

        it 'marks all items as proofable and adds markers for nested manifestations' do
          # Both the top-level manifestation and the nested collection should be proofable
          expect(response.body).to have_css('.by-card-v02.proofable', count: 2)
          # The nested collection should be proofable
          collection_item = collection.collection_items.find { |ci| ci.item_type == 'Collection' }
          expect(response.body).to have_css(
            ".proofable[data-item-id='#{collection_item.item_id}'][data-item-type='Collection']"
          )
          # The nested manifestation should have a marker div inside the nested collection
          expect(response.body).to have_css(
            ".nested-manifestation-marker[data-item-id='#{nested_manifestation.id}'][data-item-type='Manifestation']"
          )
        end
      end
    end

    context 'when collection is periodical' do
      let(:issues) { create_list(:collection, 3, collection_type: 'periodical_issue') }
      let(:nested_collections) do
        # item of 'other' type should be ignored
        issues + [create(:collection, collection_type: 'other')]
      end

      let(:collection) do
        create(
          :collection,
          collection_type: 'periodical',
          manifestations: create_list(:manifestation, 2),
          included_collections: nested_collections
        )
      end

      it 'marks periodical issues divs as proofable' do
        expect(response.body).to have_css('.by-card-v02.proofable', count: 3)
        collection.collection_items.select { |ci| issues.include?(ci.item) }.each do |ci|
          expect(response.body).to have_css(".proofable[data-item-id='#{ci.item_id}'][data-item-type='Collection']")
        end
      end
    end

    context 'when collection is volume_series' do
      subject! { get :show, params: { id: collection.id } }

      let(:volumes) { create_list(:collection, 3, collection_type: 'volume') }
      let(:nested_collections) do
        # item of 'other' type should be ignored
        volumes + [create(:collection, collection_type: 'other')]
      end

      let(:collection) do
        create(
          :collection,
          collection_type: 'volume_series',
          manifestations: create_list(:manifestation, 2),
          included_collections: nested_collections
        )
      end

      it 'marks volume divs as proofable (like periodicals)' do
        expect(response.body).to have_css('.by-card-v02.proofable', count: 3)
        collection.collection_items.select { |ci| volumes.include?(ci.item) }.each do |ci|
          expect(response.body).to have_css(".proofable[data-item-id='#{ci.item_id}'][data-item-type='Collection']")
        end
      end
    end
  end

  describe '#show with search query parameter' do
    it 'accepts query parameter and renders successfully' do
      get :show, params: { id: collection.id, q: 'search term' }
      expect(response).to be_successful
    end
  end

  describe 'editor actions' do
    include_context 'when editor logged in'

    describe '#create' do
      subject(:call) { post :create, params: { collection: collection_params } }

      let(:toc) { create(:toc) }
      let(:publication) { create(:publication) }

      let(:collection_params) do
        {
          title: title,
          sort_title: title,
          subtitle: Faker::Book.title,
          issn: 'new_issn',
          collection_type: 'volume',
          inception: 'new_inception',
          inception_year: 2024,
          publication_id: publication.id,
          toc_id: toc.id,
          toc_strategy: 'default'
        }
      end

      context 'when params are valid' do
        let(:title) { Faker::Book.title }

        it 'creates record' do
          expect { call }.to change(Collection, :count).by(1)
          collection = Collection.order(id: :desc).first
          expect(collection).to have_attributes(collection_params)
        end
      end

      context 'when params are invalid' do
        let(:title) { '' }

        it 'rejects the submission as unprocessable' do
          expect { call }.to not_change(Collection, :count)
          expect(call).to have_http_status(:unprocessable_content)
        end
      end
    end

    describe '#update' do
      subject(:call) { patch :update, params: { id: collection.id, collection: collection_params } }

      let(:toc) { create(:toc) }
      let(:publication) { create(:publication) }

      let(:collection_params) do
        {
          title: title,
          sort_title: title,
          subtitle: Faker::Book.title,
          issn: 'new_issn',
          collection_type: 'volume',
          inception: 'new_inception',
          inception_year: 2024,
          publication_id: publication.id,
          toc_id: toc.id,
          toc_strategy: 'default'
        }
      end

      context 'when params are valid' do
        let(:title) { Faker::Book.title }

        it 'updates record' do
          expect(call).to redirect_to collection
          expect(flash.notice).to eq I18n.t(:updated_successfully)
          collection.reload
          expect(collection).to have_attributes(collection_params)
        end
      end

      context 'when params are invalid' do
        let(:title) { '' }

        it 'rejects the submission as unprocessable' do
          expect(call).to have_http_status(:unprocessable_content)
        end
      end
    end

    describe '#destroy' do
      subject(:call) { delete :destroy, params: { id: collection.id } }

      before do
        collection
      end

      it 'removes record' do
        expect { call }.to change(Collection, :count).by(-1)
        expect(call).to redirect_to collections_path
        expect(flash.notice).to eq I18n.t(:deleted_successfully)
      end
    end
  end

  describe '#add_external_link' do
    include_context 'when editor logged in'

    let(:collection) { create(:collection) }

    context 'with valid parameters' do
      it 'creates an external link for the collection' do
        expect do
          post :add_external_link, params: {
            collection_id: collection.id,
            url: 'https://example.com',
            linktype: 'publisher_site',
            description: 'Test Publisher'
          }, format: :js
        end.to change(ExternalLink, :count).by(1)

        link = collection.external_links.last
        expect(link.url).to eq 'https://example.com'
        expect(link.linktype).to eq 'publisher_site'
        expect(link.description).to eq 'Test Publisher'
        expect(link.status).to eq 'approved'
      end

      it 'returns success' do
        post :add_external_link, params: {
          collection_id: collection.id,
          url: 'https://example.com',
          linktype: 'publisher_site',
          description: 'Test Publisher'
        }, format: :js
        expect(response).to be_successful
      end
    end

    describe '#create_periodical_with_issue' do
      subject(:call) do
        post :create_periodical_with_issue, params: params_hash
      end

      context 'when params are valid' do
        let(:params_hash) { { periodical_title: 'Test Periodical', issue_title: 'Issue 1' } }

        it 'creates periodical and first issue' do
          expect { call }.to change(Collection, :count).by(2)

          response_json = response.parsed_body
          expect(response_json['success']).to be true

          periodical = Collection.find(response_json['periodical_id'])
          expect(periodical.title).to eq 'Test Periodical'
          expect(periodical.collection_type).to eq 'periodical'

          issue = Collection.find(response_json['issue_id'])
          expect(issue.title).to eq 'Issue 1'
          expect(issue.collection_type).to eq 'periodical_issue'

          # Check that issue is included in periodical
          expect(periodical.coll_items).to include(issue)
        end
      end

      context 'when periodical title is blank' do
        let(:params_hash) { { periodical_title: '', issue_title: 'Issue 1' } }

        it 'returns error json' do
          expect { call }.to not_change(Collection, :count)
          expect(response).to have_http_status(:unprocessable_content)

          response_json = response.parsed_body
          expect(response_json['success']).to be false
          expect(response_json['error']).to be_present
        end
      end

      context 'when issue title is blank' do
        let(:params_hash) { { periodical_title: 'Test Periodical', issue_title: '' } }

        it 'returns error json' do
          expect { call }.to not_change(Collection, :count)
          expect(response).to have_http_status(:unprocessable_content)

          response_json = response.parsed_body
          expect(response_json['success']).to be false
          expect(response_json['error']).to be_present
        end
      end

      context 'when periodical_title parameter is missing' do
        let(:params_hash) { { issue_title: 'Issue 1' } }

        it 'returns error json' do
          expect { call }.to not_change(Collection, :count)
          expect(response).to have_http_status(:unprocessable_content)

          response_json = response.parsed_body
          expect(response_json['success']).to be false
          expect(response_json['error']).to be_present
        end
      end

      context 'when issue_title parameter is missing' do
        let(:params_hash) { { periodical_title: 'Test Periodical' } }

        it 'returns error json' do
          expect { call }.to not_change(Collection, :count)
          expect(response).to have_http_status(:unprocessable_content)

          response_json = response.parsed_body
          expect(response_json['success']).to be false
          expect(response_json['error']).to be_present
        end
      end
    end
  end

  describe '#remove_external_link' do
    include_context 'when editor logged in'

    let(:collection) { create(:collection) }
    let!(:external_link) do
      create(:external_link, linkable: collection, linktype: :publisher_site, url: 'https://example.com',
                             description: 'Test Publisher')
    end

    it 'removes the external link' do
      expect do
        post :remove_external_link, params: {
          collection_id: collection.id,
          link_id: external_link.id
        }
      end.to change(ExternalLink, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end

    it 'returns error for non-existent link' do
      post :remove_external_link, params: {
        collection_id: collection.id,
        link_id: 999_999
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe '#browse' do
    after do
      Chewy.massacre
    end

    let!(:volume_1) { create(:collection, title: 'Alpha Volume', collection_type: :volume, sort_title: 'alpha volume') }
    let!(:volume_2) { create(:collection, title: 'Beta Volume', collection_type: :volume, sort_title: 'beta volume') }
    let!(:periodical) { create(:collection, title: 'Gamma Periodical', collection_type: :periodical, sort_title: 'gamma periodical') }
    let!(:series) { create(:collection, title: 'Delta Series', collection_type: :series, sort_title: 'delta series') }

    before do
      Chewy.strategy(:atomic) do
        volume_1
        volume_2
        periodical
        series
      end
    end

    context 'when requesting HTML' do
      it 'renders the browse template' do
        get :browse
        expect(response).to be_successful
        expect(response).to render_template(:browse)
      end

      it 'assigns collections list title' do
        get :browse
        expect(assigns(:collections_list_title)).to be_present
      end

      it 'assigns collections variable with results' do
        get :browse
        expect(assigns(:collections)).to be_present
        expect(assigns(:collections).count).to eq(4)
      end
    end

    context 'when requesting JS (AJAX)' do
      it 'renders the JS template' do
        get :browse, format: :js, xhr: true
        expect(response).to be_successful
        expect(response.content_type).to include('text/javascript')
      end
    end

    context 'with filters' do
      it 'filters by collection type' do
        get :browse, params: { ckb_collection_types: ['volume'] }
        expect(response).to be_successful
        expect(assigns(:collections).map(&:id)).to contain_exactly(volume_1.id, volume_2.id)
      end

      it 'filters by title search' do
        get :browse, params: { search_input: 'Alpha' }
        expect(response).to be_successful
        expect(assigns(:collections).map(&:id)).to contain_exactly(volume_1.id)
      end

      it 'filters by multiple collection types' do
        get :browse, params: { ckb_collection_types: ['volume', 'series'] }
        expect(response).to be_successful
        expect(assigns(:collections).map(&:id)).to contain_exactly(volume_1.id, volume_2.id, series.id)
      end
    end

    context 'with sorting' do
      it 'sorts alphabetically by default' do
        get :browse
        expect(assigns(:sort_by)).to eq('alphabetical')
        expect(assigns(:collections).map(&:id)).to eq([volume_1.id, volume_2.id, series.id, periodical.id])
      end

      it 'sorts by popularity when requested' do
        volume_1.update!(impressions_count: 100)
        series.update!(impressions_count: 50)
        periodical.update!(impressions_count: 75)
        volume_2.update!(impressions_count: 25)

        Chewy.strategy(:atomic) do
          CollectionsIndex.import([volume_1, volume_2, periodical, series])
        end

        get :browse, params: { sort_by: 'popularity_desc' }
        expect(assigns(:sort_by)).to eq('popularity')
        expect(assigns(:collections).map(&:id)).to eq([volume_1.id, periodical.id, series.id, volume_2.id])
      end

      it 'sorts by publication date when requested' do
        volume_1.update!(normalized_pub_year: 2000)
        volume_2.update!(normalized_pub_year: 1990)
        periodical.update!(normalized_pub_year: 1980)
        series.update!(normalized_pub_year: 2010)

        Chewy.strategy(:atomic) do
          CollectionsIndex.import([volume_1, volume_2, periodical, series])
        end

        get :browse, params: { sort_by: 'publication_date_asc' }
        expect(assigns(:sort_by)).to eq('publication_date')
        expect(assigns(:collections).map(&:id)).to eq([periodical.id, volume_2.id, volume_1.id, series.id])
      end
    end

    context 'with invalid query' do
      it 'returns bad request for invalid to_letter parameter' do
        get :browse, params: { to_letter: 'invalid' }
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with combined filters' do
      it 'applies multiple filters together' do
        get :browse, params: { ckb_collection_types: ['volume'], search_input: 'Alpha' }
        expect(response).to be_successful
        expect(assigns(:collections).map(&:id)).to contain_exactly(volume_1.id)
      end
    end
  end
end
