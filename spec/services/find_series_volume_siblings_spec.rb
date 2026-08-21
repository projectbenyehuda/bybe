# frozen_string_literal: true

require 'rails_helper'

describe FindSeriesVolumeSiblings do
  subject(:result) { described_class.call(volume) }

  let(:series) { create(:collection, collection_type: :volume_series) }
  let(:vol1) { create(:collection, collection_type: :volume) }
  let(:vol2) { create(:collection, collection_type: :volume) }
  let(:vol3) { create(:collection, collection_type: :volume) }

  # volume_series layout:
  #   seqno 1 → vol1
  #   seqno 2 → vol2
  #   seqno 3 → vol3
  before do
    series.collection_items.create!(item: vol1, seqno: 1)
    series.collection_items.create!(item: vol2, seqno: 2)
    series.collection_items.create!(item: vol3, seqno: 3)
  end

  context 'when the volume is the first in the series' do
    let(:volume) { vol1 }

    it 'exposes the containing series' do
      expect(result.series).to eq(series)
    end

    it 'returns nil for prev_volume' do
      expect(result.prev_volume).to be_nil
    end

    it 'returns the next volume' do
      expect(result.next_volume).to eq(vol2)
    end
  end

  context 'when the volume is in the middle of the series' do
    let(:volume) { vol2 }

    it 'returns the previous volume' do
      expect(result.prev_volume).to eq(vol1)
    end

    it 'returns the next volume' do
      expect(result.next_volume).to eq(vol3)
    end
  end

  context 'when the volume is the last in the series' do
    let(:volume) { vol3 }

    it 'returns the previous volume' do
      expect(result.prev_volume).to eq(vol2)
    end

    it 'returns nil for next_volume' do
      expect(result.next_volume).to be_nil
    end
  end

  context 'when the volume has no volume_series parent' do
    let(:volume) { create(:collection, collection_type: :volume) }

    it 'returns nil for series, prev_volume and next_volume' do
      expect(result.series).to be_nil
      expect(result.prev_volume).to be_nil
      expect(result.next_volume).to be_nil
    end
  end

  context 'when the series also contains non-volume items' do
    subject(:result) { described_class.call(vol_a) }

    let(:other_series) { create(:collection, collection_type: :volume_series) }
    let(:vol_a) { create(:collection, collection_type: :volume) }
    let(:vol_b) { create(:collection, collection_type: :volume) }
    let(:sub_series) { create(:collection, collection_type: :series) }
    let(:loose_manifestation) { create(:manifestation) }

    # Interleave a non-volume collection and a direct manifestation between the volumes
    before do
      other_series.collection_items.create!(item: vol_a, seqno: 1)
      other_series.collection_items.create!(item: sub_series, seqno: 2)
      other_series.collection_items.create!(item: loose_manifestation, seqno: 3)
      other_series.collection_items.create!(item: vol_b, seqno: 4)
    end

    it 'navigates only among volume-type siblings, skipping the others' do
      expect(result.next_volume).to eq(vol_b)
    end
  end
end
