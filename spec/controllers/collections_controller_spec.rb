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

    context 'when collection is not periodical' do
      let(:collection_type) { (Collection.collection_types.keys - ['periodical'] - Collection::SYSTEM_TYPES).sample }

      context 'when collection contains manifestations' do
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
  end

  describe '#show with search query parameter' do
    subject { get :show, params: { id: collection.id, q: 'search term' } }

    it 'accepts query parameter and renders successfully' do
      expect(subject).to be_successful
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
end
