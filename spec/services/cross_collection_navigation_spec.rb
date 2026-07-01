# frozen_string_literal: true

require 'rails_helper'

describe CrossCollectionNavigation do
  subject(:result) { described_class.call(manifestation, sub_collection) }

  let(:volume) { create(:collection, collection_type: :volume) }
  let(:sub_a) { create(:collection, collection_type: :series) }
  let(:sub_b) { create(:collection, collection_type: :series) }
  let(:m1) { create(:manifestation) }
  let(:m2) { create(:manifestation) }
  let(:m3) { create(:manifestation) }
  let(:m4) { create(:manifestation) }
  let(:m5) { create(:manifestation) }

  # Volume layout:
  #   seqno 1 → sub_a  (series)
  #     seqno 1 → m1
  #     seqno 2 → m2
  #   seqno 2 → m3  (direct manifestation in volume)
  #   seqno 3 → sub_b  (series)
  #     seqno 1 → m4
  #     seqno 2 → m5
  before do
    volume.collection_items.create!(item: sub_a, seqno: 1)
    volume.collection_items.create!(item: m3, seqno: 2)
    volume.collection_items.create!(item: sub_b, seqno: 3)
    sub_a.collection_items.create!(item: m1, seqno: 1)
    sub_a.collection_items.create!(item: m2, seqno: 2)
    sub_b.collection_items.create!(item: m4, seqno: 1)
    sub_b.collection_items.create!(item: m5, seqno: 2)
  end

  context 'when sub_collection has no volume/issue parent' do
    subject(:result) { described_class.call(manifestation, orphan_collection) }

    let(:orphan_collection) { create(:collection, collection_type: :series) }
    let(:manifestation) { create(:manifestation) }

    before { orphan_collection.collection_items.create!(item: manifestation, seqno: 1) }

    it 'returns nil for both prev and next' do
      expect(result.prev_in_parent).to be_nil
      expect(result.next_in_parent).to be_nil
    end
  end

  context 'when manifestation is first in sub_a (first sub-collection)' do
    let(:manifestation) { m1 }
    let(:sub_collection) { sub_a }

    it 'returns nil for prev (first in volume)' do
      expect(result.prev_in_parent).to be_nil
    end

    it 'returns m2 as next (still within sub_a)' do
      expect(result.next_in_parent).to eq(m2)
    end
  end

  context 'when manifestation is last in sub_a' do
    let(:manifestation) { m2 }
    let(:sub_collection) { sub_a }

    it 'returns m1 as prev' do
      expect(result.prev_in_parent).to eq(m1)
    end

    it 'returns m3 (direct volume item) as next' do
      expect(result.next_in_parent).to eq(m3)
    end
  end

  context 'when manifestation is first in sub_b' do
    let(:manifestation) { m4 }
    let(:sub_collection) { sub_b }

    it 'returns m3 (direct volume item) as prev' do
      expect(result.prev_in_parent).to eq(m3)
    end

    it 'returns m5 as next (still within sub_b)' do
      expect(result.next_in_parent).to eq(m5)
    end
  end

  context 'when manifestation is last in sub_b (last sub-collection)' do
    let(:manifestation) { m5 }
    let(:sub_collection) { sub_b }

    it 'returns m4 as prev' do
      expect(result.prev_in_parent).to eq(m4)
    end

    it 'returns nil for next (last in volume)' do
      expect(result.next_in_parent).to be_nil
    end
  end

  context 'with a periodical_issue parent' do
    let(:issue) { create(:collection, collection_type: :periodical_issue) }
    let(:series) { create(:collection, collection_type: :series) }
    let(:article1) { create(:manifestation) }
    let(:article2) { create(:manifestation) }
    let(:poem) { create(:manifestation) }

    before do
      issue.collection_items.create!(item: article1, seqno: 1)
      issue.collection_items.create!(item: series, seqno: 2)
      series.collection_items.create!(item: poem, seqno: 1)
      issue.collection_items.create!(item: article2, seqno: 3)
    end

    context 'when at last item in series' do
      subject(:result) { described_class.call(poem, series) }

      it 'returns article1 as prev' do
        expect(result.prev_in_parent).to eq(article1)
      end

      it 'returns article2 as next' do
        expect(result.next_in_parent).to eq(article2)
      end
    end
  end

  context 'when volume has a placeholder item' do
    subject(:result) { described_class.call(ma, sub) }

    let(:volume_with_placeholder) { create(:collection, collection_type: :volume) }
    let(:sub) { create(:collection, collection_type: :series) }
    let(:ma) { create(:manifestation) }
    let(:mb) { create(:manifestation) }

    before do
      volume_with_placeholder.collection_items.create!(item: sub, seqno: 1)
      volume_with_placeholder.collection_items.create!(alt_title: 'Placeholder', seqno: 2)
      volume_with_placeholder.collection_items.create!(item: mb, seqno: 3)
      sub.collection_items.create!(item: ma, seqno: 1)
    end

    it 'skips the placeholder and returns mb as next' do
      expect(result.next_in_parent).to eq(mb)
    end
  end
end
