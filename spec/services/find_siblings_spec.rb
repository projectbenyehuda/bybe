# frozen_string_literal: true

require 'rails_helper'

describe FindSiblings do
  subject(:result) { described_class.call(manifestation, collection) }

  let(:previous_sibling) { result.previous_sibling }
  let(:next_sibling) { result.next_sibling }

  let(:collection) { create(:collection) }
  let(:manifestation_1) { create(:manifestation) }
  let(:manifestation_2) { create(:manifestation) }
  let(:manifestation_3) { create(:manifestation) }

  before do
    collection.collection_items.create!(alt_title: 'placeholder_1', seqno: 1)
    collection.collection_items.create!(item: manifestation_1, seqno: 2)
    collection.collection_items.create!(item: manifestation_2, seqno: 3)
    collection.collection_items.create!(alt_title: 'placeholder_2', seqno: 4)
    collection.collection_items.create!(paratext: 'placeholder_3', seqno: 5)
    collection.collection_items.create!(item: manifestation_3, seqno: 6)
  end

  context 'when first manifestation is given' do
    let(:manifestation) { manifestation_1 }

    it 'finds next sibling but no previous sibling' do
      expect(previous_sibling).to be_nil
      expect(next_sibling).to eq({ item: manifestation_2, skipped: 0 })
    end
  end

  context 'when second manifestation is given' do
    let(:manifestation) { manifestation_2 }

    it 'finds both previous and next siblings' do
      expect(previous_sibling).to eq({ item: manifestation_1, skipped: 0 })
      expect(next_sibling).to eq({ item: manifestation_3, skipped: 2 })
    end
  end

  context 'when third manifestation is given' do
    let(:manifestation) { manifestation_3 }

    it 'finds previous sibling but no next sibling' do
      expect(previous_sibling).to eq({ item: manifestation_2, skipped: 2 })
      expect(next_sibling).to be_nil
    end
  end

  context 'when manifestation is not in collection' do
    let(:manifestation) { create(:manifestation) }

    it 'raises an error' do
      expect { result }.to raise_error('Item not found in collection')
    end
  end
end
