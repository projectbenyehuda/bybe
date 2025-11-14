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

    describe '#drag_item' do
      subject(:call) { post :drag_item, params: { id: collection.id, old_index: old_index, new_index: new_index } }

      let(:titles) { Array.new(5) { |index| (index + 1).to_s } }
      let!(:collection) { create(:collection, title_placeholders: titles) }
      let(:collection_item) { collection.collection_items[old_index] }

      shared_examples 'drags successfully' do
        it 'moves item to new position' do
          expect(call).to be_successful
          expect(collection_item.reload.seqno).to eq(new_index + 1)
          collection.reload
          expect(collection.collection_items.pluck(:alt_title)).to eq(expected_order)
          expect(collection.collection_items.pluck(:seqno)).to eq([1, 2, 3, 4, 5])
        end
      end

      context 'when we drag item forwards' do
        let(:old_index) { 0 }
        let(:new_index) { 2 }
        let(:expected_order) { %w(2 3 1 4 5) }

        it_behaves_like 'drags successfully'
      end

      context 'when we drag item backwards' do
        let(:old_index) { 2 }
        let(:new_index) { 0 }
        let(:expected_order) { %w(3 1 2 4 5) }

        it_behaves_like 'drags successfully'
      end
    end

    describe '#transplant_item' do
      subject(:call) do
        post :transplant_item, params: {
          collection_id: src_collection.id,
          dest_coll_id: dest_collection.id,
          src_coll_id: src_collection.id,
          item_id: item_to_move.id,
          new_pos: new_pos
        }
      end

      let(:src_titles) { %w(A B C D E) }
      let(:dest_titles) { %w(1 2 3) }
      let!(:src_collection) { create(:collection, title_placeholders: src_titles) }
      let!(:dest_collection) { create(:collection, title_placeholders: dest_titles) }
      let(:item_to_move) { src_collection.collection_items[2] } # Item 'C'
      let(:new_pos) { 2 } # Insert at position 2 (between '1' and '2')

      it 'moves item from source to destination collection' do
        expect { call }.to change { src_collection.collection_items.reload.count }.by(-1)
                       .and change { dest_collection.collection_items.reload.count }.by(1)

        # Verify source collection has correct items and order
        src_collection.reload
        expect(src_collection.collection_items.pluck(:alt_title)).to eq(%w(A B D E))
        expect(src_collection.collection_items.pluck(:seqno)).to eq([1, 2, 4, 5])

        # Verify destination collection has correct items and order
        dest_collection.reload
        expect(dest_collection.collection_items.pluck(:alt_title)).to eq(%w(1 C 2 3))
        expect(dest_collection.collection_items.pluck(:seqno)).to eq([1, 2, 3, 4])
      end

      it 'removes the original item from source collection' do
        original_item_id = item_to_move.id
        call
        expect(CollectionItem.where(id: original_item_id).exists?).to be_falsey
      end

      context 'when destination collection has gaps in seqno' do
        let(:dest_titles) { %w(X Y Z) }
        let!(:dest_collection) { create(:collection, title_placeholders: dest_titles) }
        let(:new_pos) { 2 }

        before do
          # Create gaps in seqno: change [1, 2, 3] to [1, 5, 10]
          dest_collection.collection_items.reload
          dest_collection.collection_items[1].update!(seqno: 5)
          dest_collection.collection_items[2].update!(seqno: 10)
        end

        it 'inserts item correctly despite gaps' do
          call
          dest_collection.reload
          expect(dest_collection.collection_items.pluck(:alt_title)).to eq(%w(X C Y Z))
          # seqno should be sequential after insert
          expect(dest_collection.collection_items.pluck(:seqno)).to eq([1, 5, 6, 11])
        end
      end

      context 'when transplanting to the beginning' do
        let(:new_pos) { 1 }

        it 'inserts item at the start' do
          call
          dest_collection.reload
          expect(dest_collection.collection_items.pluck(:alt_title)).to eq(%w(C 1 2 3))
          expect(dest_collection.collection_items.pluck(:seqno)).to eq([1, 2, 3, 4])
        end
      end

      context 'when transplanting to the end' do
        let(:new_pos) { 4 } # Position 4 is after all existing items (1, 2, 3)

        it 'inserts item at the end' do
          call
          dest_collection.reload
          expect(dest_collection.collection_items.pluck(:alt_title)).to eq(%w(1 2 3 C))
          expect(dest_collection.collection_items.pluck(:seqno)).to eq([1, 2, 3, 4])
        end
      end

      context 'when transplanting beyond the end' do
        let(:new_pos) { 100 } # Way beyond current size

        it 'inserts item at the end' do
          call
          dest_collection.reload
          expect(dest_collection.collection_items.pluck(:alt_title)).to eq(%w(1 2 3 C))
          # Should append after the last item
          expect(dest_collection.collection_items.last.seqno).to be > dest_collection.collection_items[-2].seqno
        end
      end

      context 'when performing multiple sequential transplants' do
        let(:item_to_move1) { src_collection.collection_items[0] } # Item 'A'
        let(:item_to_move2) { src_collection.collection_items[2] } # Item 'C'

        it 'maintains correct order after multiple operations' do
          # First transplant: Move A to dest position 2
          post :transplant_item, params: {
            collection_id: src_collection.id,
            dest_coll_id: dest_collection.id,
            src_coll_id: src_collection.id,
            item_id: item_to_move1.id,
            new_pos: 2
          }

          dest_collection.reload
          expect(dest_collection.collection_items.pluck(:alt_title)).to eq(%w(1 A 2 3))

          # Second transplant: Move C to dest position 1
          post :transplant_item, params: {
            collection_id: src_collection.id,
            dest_coll_id: dest_collection.id,
            src_coll_id: src_collection.id,
            item_id: item_to_move2.id,
            new_pos: 1
          }

          dest_collection.reload
          expect(dest_collection.collection_items.pluck(:alt_title)).to eq(%w(C 1 A 2 3))
          # Verify seqno values are sequential
          seqnos = dest_collection.collection_items.pluck(:seqno)
          expect(seqnos).to eq(seqnos.sort)
        end
      end

      context 'when source collection has gaps in seqno' do
        before do
          # Create gaps in source: [1, 2, 3, 4, 5] -> [1, 3, 7, 10, 15]
          src_collection.collection_items.reload
          src_collection.collection_items[1].update!(seqno: 3)
          src_collection.collection_items[2].update!(seqno: 7)
          src_collection.collection_items[3].update!(seqno: 10)
          src_collection.collection_items[4].update!(seqno: 15)
        end

        it 'handles source gaps correctly' do
          # item_to_move is collection_items[2], which now has seqno: 7
          call
          dest_collection.reload
          expect(dest_collection.collection_items.pluck(:alt_title)).to eq(%w(1 C 2 3))
          expect(dest_collection.collection_items.pluck(:seqno)).to eq([1, 2, 3, 4])

          # Verify source still has its remaining items in correct order
          src_collection.reload
          expect(src_collection.collection_items.pluck(:alt_title)).to eq(%w(A B D E))
        end
      end



      context 'when transplanting multiple items to trigger append beyond stale size' do
        let(:src_titles2) { %w(X Y Z) }
        let!(:src_collection2) { create(:collection, title_placeholders: src_titles2) }

        it 'correctly appends when position exceeds size' do
          # First transplant - adds item to dest
          first_item = src_collection.collection_items[0] # 'A'
          post :transplant_item, params: {
            collection_id: src_collection.id,
            dest_coll_id: dest_collection.id,
            src_coll_id: src_collection.id,
            item_id: first_item.id,
            new_pos: 2
          }

          # Second transplant - try to append at position 10 (way beyond size)
          # If association is cached from first call, this tests pos > cached_size
          second_item = src_collection2.collection_items[0] # 'X'
          post :transplant_item, params: {
            collection_id: src_collection2.id,
            dest_coll_id: dest_collection.id,
            src_coll_id: src_collection2.id,
            item_id: second_item.id,
            new_pos: 10  # Way beyond actual size (4)
          }

          # Verify final order
          dest_collection.reload
          titles = dest_collection.collection_items.pluck(:alt_title)
          seqnos = dest_collection.collection_items.pluck(:seqno)

          # Should have 5 items with sequential seqnos
          expect(titles.size).to eq(5)
          expect(seqnos).to eq([1, 2, 3, 4, 5])  # Should be sequential

          # X should be appended at the end
          expect(titles.last).to eq('X')
        end
      end
    end
  end
end
