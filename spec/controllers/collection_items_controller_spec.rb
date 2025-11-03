# frozen_string_literal: true

require 'rails_helper'

describe CollectionItemsController do
  include_context 'when editor logged in'

  describe '#drag_item' do
    subject(:call) { post :drag_item, params: { id: collection_item.id, old_index: old_index, new_index: new_index } }

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

    context 'when old_index does not match actual position' do
      let(:old_index) { 0 }
      let(:new_index) { 2 }
      let(:collection_item) { collection.collection_items[2] }

      it 'returns bad request' do
        expect(call).to have_http_status(:bad_request)
      end
    end
  end

  describe '#transplant_item' do
    subject(:call) do
      post :transplant_item, params: {
        id: item_to_move.id,
        dest_coll_id: dest_collection.id,
        new_index: new_index
      }
    end

    let(:src_titles) { %w(A B C D E) }
    let(:dest_titles) { %w(1 2 3) }
    let!(:src_collection) { create(:collection, title_placeholders: src_titles) }
    let!(:dest_collection) { create(:collection, title_placeholders: dest_titles) }
    let(:item_to_move) { src_collection.collection_items[2] } # Item 'C'
    let(:new_index) { 2 } # Insert at position 2 (between '2' and '3')

    it 'moves item from source to destination collection' do
      expect { call }.to change { src_collection.collection_items.reload.count }.by(-1)
                     .and change { dest_collection.collection_items.reload.count }.by(1)

      # Verify source collection has correct items and order with cleaned up seqno
      src_collection.reload
      expect(src_collection.collection_items.pluck(:alt_title)).to eq(%w(A B D E))
      expect(src_collection.collection_items.pluck(:seqno)).to eq([1, 2, 3, 4])

      # Verify destination collection has correct items and order
      dest_collection.reload
      expect(dest_collection.collection_items.pluck(:alt_title)).to eq(%w(1 2 C 3))
      expect(dest_collection.collection_items.pluck(:seqno)).to eq([1, 2, 3, 4])

      # Ensure item is moved to destination collection
      item_to_move.reload
      expect(item_to_move.collection).to eq(dest_collection)
    end

    context 'when destination collection matches source collection' do
      let(:dest_collection) { src_collection }

      it 'fails with bad request' do
        expect(call).to be_bad_request
        expect(response.body).to eq('Destination collection cannot be the same as source collection')
      end
    end

    context 'when new_index is negative' do
      let(:new_index) { -1 }

      it 'fails with bad request' do
        expect(call).to be_bad_request
        expect(response.body).to eq('Wrong new_index')
      end
    end

    context 'when new_index is greater than number of items in destination collection' do
      let(:new_index) { 4 }

      it 'fails with bad request' do
        expect(call).to be_bad_request
        expect(response.body).to eq('Wrong new_index')
      end
    end
  end
end
