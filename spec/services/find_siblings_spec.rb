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

    it 'reports more_before? true (non-paratext placeholder exists before) and more_after? true' do
      expect(result.more_before?).to be true
      expect(result.more_after?).to be true
    end
  end

  context 'when second manifestation is given' do
    let(:manifestation) { manifestation_2 }

    it 'finds both previous and next siblings' do
      expect(previous_sibling).to eq({ item: manifestation_1, skipped: 0 })
      expect(next_sibling).to eq({ item: manifestation_3, skipped: 2 })
    end

    it 'reports more_before? and more_after? true' do
      expect(result.more_before?).to be true
      expect(result.more_after?).to be true
    end
  end

  context 'when third manifestation is given' do
    let(:manifestation) { manifestation_3 }

    it 'finds previous sibling but no next sibling' do
      expect(previous_sibling).to eq({ item: manifestation_2, skipped: 2 })
      expect(next_sibling).to be_nil
    end

    it 'reports more_before? true and more_after? false (truly last item)' do
      expect(result.more_before?).to be true
      expect(result.more_after?).to be false
    end
  end

  context 'when manifestation is last uploaded item but placeholders follow' do
    subject(:result) { described_class.call(manifestation_a, collection_with_trailing_placeholders) }

    let(:collection_with_trailing_placeholders) { create(:collection) }
    let(:manifestation_a) { create(:manifestation) }

    before do
      collection_with_trailing_placeholders.collection_items.create!(item: manifestation_a, seqno: 1)
      collection_with_trailing_placeholders.collection_items.create!(alt_title: 'placeholder_after', seqno: 2)
    end

    it 'finds no next sibling but reports more_after? true' do
      expect(result.next_sibling).to be_nil
      expect(result.more_after?).to be true
    end
  end

  context 'when manifestation is last real item and only paratexts follow' do
    subject(:result) { described_class.call(manifestation_b, collection_with_trailing_paratexts) }

    let(:collection_with_trailing_paratexts) { create(:collection) }
    let(:manifestation_b) { create(:manifestation) }

    before do
      collection_with_trailing_paratexts.collection_items.create!(item: manifestation_b, seqno: 1)
      collection_with_trailing_paratexts.collection_items.create!(paratext: true, seqno: 2)
    end

    it 'finds no next sibling and reports more_after? false' do
      expect(result.next_sibling).to be_nil
      expect(result.more_after?).to be false
    end
  end

  context 'when manifestation is not in collection' do
    let(:manifestation) { create(:manifestation) }

    it 'raises an error' do
      expect { result }.to raise_error('Item not found in collection')
    end
  end

  context 'when next sibling is a sub-collection' do
    subject(:result) { described_class.call(manifestation_a, parent_col) }

    let(:parent_col) { create(:collection) }
    let(:sub_col) { create(:collection) }
    let(:manifestation_a) { create(:manifestation) }
    let(:manifestation_b) { create(:manifestation) }
    let(:manifestation_c) { create(:manifestation) }

    before do
      parent_col.collection_items.create!(item: manifestation_a, seqno: 1)
      parent_col.collection_items.create!(item: sub_col, seqno: 2)
      sub_col.collection_items.create!(item: manifestation_b, seqno: 1)
      sub_col.collection_items.create!(item: manifestation_c, seqno: 2)
    end

    it 'drills into the sub-collection and returns its first manifestation as next' do
      expect(result.next_sibling).to eq({ item: manifestation_b, skipped: 0 })
    end

    it 'returns nil as previous' do
      expect(result.previous_sibling).to be_nil
    end
  end

  context 'when previous sibling is a sub-collection' do
    subject(:result) { described_class.call(manifestation_c, parent_col) }

    let(:parent_col) { create(:collection) }
    let(:sub_col) { create(:collection) }
    let(:manifestation_a) { create(:manifestation) }
    let(:manifestation_b) { create(:manifestation) }
    let(:manifestation_c) { create(:manifestation) }

    before do
      parent_col.collection_items.create!(item: sub_col, seqno: 1)
      sub_col.collection_items.create!(item: manifestation_a, seqno: 1)
      sub_col.collection_items.create!(item: manifestation_b, seqno: 2)
      parent_col.collection_items.create!(item: manifestation_c, seqno: 2)
    end

    it 'drills into the sub-collection and returns its last manifestation as previous' do
      expect(result.previous_sibling).to eq({ item: manifestation_b, skipped: 0 })
    end

    it 'returns nil as next' do
      expect(result.next_sibling).to be_nil
    end
  end

  context 'when next sibling sub-collection has no manifestations (all placeholders)' do
    subject(:result) { described_class.call(manifestation_a, parent_col) }

    let(:parent_col) { create(:collection) }
    let(:empty_sub) { create(:collection) }
    let(:manifestation_a) { create(:manifestation) }
    let(:manifestation_b) { create(:manifestation) }

    before do
      parent_col.collection_items.create!(item: manifestation_a, seqno: 1)
      parent_col.collection_items.create!(item: empty_sub, seqno: 2)
      empty_sub.collection_items.create!(alt_title: 'placeholder', seqno: 1)
      parent_col.collection_items.create!(item: manifestation_b, seqno: 3)
    end

    it 'skips the empty sub-collection and returns the next real manifestation' do
      expect(result.next_sibling).to eq({ item: manifestation_b, skipped: 1 })
    end
  end

  context 'when next sibling sub-collection contains a nested sub-collection' do
    subject(:result) { described_class.call(manifestation_a, parent_col) }

    let(:parent_col) { create(:collection) }
    let(:sub_col) { create(:collection) }
    let(:nested_sub) { create(:collection) }
    let(:manifestation_a) { create(:manifestation) }
    let(:manifestation_b) { create(:manifestation) }

    before do
      parent_col.collection_items.create!(item: manifestation_a, seqno: 1)
      parent_col.collection_items.create!(item: sub_col, seqno: 2)
      sub_col.collection_items.create!(item: nested_sub, seqno: 1)
      nested_sub.collection_items.create!(item: manifestation_b, seqno: 1)
    end

    it 'drills recursively into nested sub-collections to find the first manifestation' do
      expect(result.next_sibling).to eq({ item: manifestation_b, skipped: 0 })
    end
  end
end
