# frozen_string_literal: true

require 'rails_helper'

describe TocTree::PlaceholderNode do
  let(:authority) { create(:authority) }
  let(:other_authority) { create(:authority) }

  def placeholder_node_in(collection)
    ci = create(:collection_item, collection: collection, alt_title: 'placeholder text', seqno: 1)
    described_class.new(ci)
  end

  describe '#visible?' do
    context 'when involved_on_collection_level is false' do
      it 'returns false regardless of collection involvement' do
        collection = create(:collection, translators: [authority])
        node = placeholder_node_in(collection)
        expect(node.visible?(:translator, authority.id, false, collection)).to be(false)
      end
    end

    context 'when involved_on_collection_level is true' do
      context 'when authority is directly involved in the immediate parent collection' do
        it 'returns true' do
          collection = create(:collection, translators: [authority])
          node = placeholder_node_in(collection)
          expect(node.visible?(:translator, authority.id, true, collection)).to be(true)
        end
      end

      context 'when authority is involved in a grandparent collection but NOT directly in the immediate parent' do
        it 'returns true (hierarchical check)' do
          parent = create(:collection) # no authority directly
          _grandparent = create(:collection, translators: [authority], included_collections: [parent])
          node = placeholder_node_in(parent)
          expect(node.visible?(:translator, authority.id, true, parent)).to be(true)
        end
      end

      context 'when authority is not involved anywhere in the hierarchy' do
        it 'returns false' do
          collection = create(:collection, authors: [other_authority])
          node = placeholder_node_in(collection)
          expect(node.visible?(:author, authority.id, true, collection)).to be(false)
        end
      end

      context 'when checking a different role than the authority has' do
        it 'returns false' do
          collection = create(:collection, translators: [authority])
          node = placeholder_node_in(collection)
          expect(node.visible?(:author, authority.id, true, collection)).to be(false)
        end
      end
    end
  end

  describe '#count_manifestations' do
    it 'always returns 0' do
      collection = create(:collection, translators: [authority])
      node = placeholder_node_in(collection)
      expect(node.count_manifestations(:translator, authority.id, true, collection)).to eq(0)
      expect(node.count_manifestations(:translator, authority.id, false, collection)).to eq(0)
    end
  end
end
