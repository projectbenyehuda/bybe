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
          # The sub-collection header, nested manifestation, and top-level manifestation should all be proofable
          expect(response.body).to have_css('.by-card-v02.proofable', count: 3)
          # The nested collection should be proofable
          collection_item = collection.collection_items.find { |ci| ci.item_type == 'Collection' }
          expect(response.body).to have_css(
            ".proofable[data-item-id='#{collection_item.item_id}'][data-item-type='Collection']"
          )
          # The nested manifestation should be proofable as its own card
          expect(response.body).to have_css(
            ".proofable[data-item-id='#{nested_manifestation.id}'][data-item-type='Manifestation']"
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

  describe '#show with translator display in TOC' do
    let(:collection_author) { create(:authority, name: 'Collection Author') }
    let(:collection_translator) { create(:authority, name: 'Collection Translator') }
    let(:work_translator) { create(:authority, name: 'Work Translator') }
    let(:manifestation) do
      create(:manifestation, title: 'Translated Work').tap do |m|
        m.expression.involved_authorities.create!(authority: work_translator, role: 'translator')
      end
    end
    let(:other_manifestation) { create(:manifestation, title: 'Other Work') }

    let(:collection) do
      create(:collection, title: 'Test Collection').tap do |coll|
        coll.involved_authorities.create!(authority: collection_author, role: 'author')
        coll.involved_authorities.create!(authority: collection_translator, role: 'translator')
        coll.collection_items.create!(item: manifestation, seqno: 1)
        coll.collection_items.create!(item: other_manifestation, seqno: 2)
      end
    end

    it 'displays work-specific translators in the TOC' do
      get :show, params: { id: collection.id }
      expect(response).to be_successful
      expect(response.body).to include('Translated Work')
      expect(response.body).to include('Work Translator')
    end

    it 'filters out collection-level translators from individual works' do
      # Add the same translator to the manifestation's expression
      manifestation.expression.involved_authorities.create!(authority: collection_translator, role: 'translator')

      get :show, params: { id: collection.id }
      expect(response).to be_successful

      # The TOC should not show collection_translator name in the item listing
      # since it's already shown at the collection level
      toc_section = response.body.match(/binder-texts-list.*?<\/div>/m).to_s
      expect(toc_section).not_to include("/ #{collection_translator.name}")
    end

    it 'displays both author and translator when both are present' do
      work_author = create(:authority, name: 'Work Author')
      # Add author to expression (not collection level, so it should appear in TOC)
      manifestation.expression.work.involved_authorities.create!(authority: work_author, role: 'author')

      get :show, params: { id: collection.id }
      expect(response).to be_successful

      # Extract the TOC section to verify format
      toc_section = response.body.match(/binder-texts-list.*?<\/ul>/m).to_s

      # Should display both author and translator in the TOC
      expect(toc_section).to include('Translated Work')
      expect(toc_section).to include('Work Author')
      expect(toc_section).to include('Work Translator')
    end
  end

  describe '#pby_volumes' do
    let(:authority) { create(:authority, id: Authority::PBY_AUTHORITY_ID) }
    let!(:pby_volume1) do
      create(:collection, collection_type: 'volume', title: 'Volume 1').tap do |vol|
        vol.involved_authorities.create!(authority: authority, role: 'editor')
      end
    end
    let!(:pby_volume2) do
      create(:collection, collection_type: 'volume', title: 'Volume 2').tap do |vol|
        vol.involved_authorities.create!(authority: authority, role: 'editor')
      end
    end
    let!(:other_volume) { create(:collection, collection_type: 'volume', title: 'Other Volume') }

    it 'renders successfully' do
      get :pby_volumes
      expect(response).to be_successful
    end

    it 'assigns pby_volumes' do
      get :pby_volumes
      expect(assigns(:pby_volumes)).to contain_exactly(pby_volume1, pby_volume2)
    end

    it 'assigns pby_volumes_count' do
      get :pby_volumes
      expect(assigns(:pby_volumes_count)).to eq(2)
    end

    it 'orders volumes by title' do
      get :pby_volumes
      expect(assigns(:pby_volumes).pluck(:title)).to eq(['Volume 1', 'Volume 2'])
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

      context 'when updating description' do
        let(:title) { Faker::Book.title }
        let(:collection_params) do
          {
            title: title,
            description: 'This is a test description for the collection'
          }
        end

        it 'updates the description field' do
          expect(call).to redirect_to collection
          collection.reload
          expect(collection.description).to eq 'This is a test description for the collection'
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
end
