# frozen_string_literal: true

require 'rails_helper'

describe RefreshUncollectedWorksCollectionJob do
  describe '#perform' do
    subject(:call) { described_class.new.perform(uncollected_works_collection_ids) }

    let!(:uncollected_collection_1) { create(:collection, :uncollected) }
    let!(:uncollected_collection_2) { create(:collection, :uncollected) }
    let!(:uncollected_collection_3) { create(:collection, :uncollected) }

    let!(:authority_1) { create(:authority, uncollected_works_collection: uncollected_collection_1) }
    let!(:authority_2) { create(:authority, uncollected_works_collection: uncollected_collection_2) }
    let!(:non_matching_authority) { create(:authority, uncollected_works_collection: uncollected_collection_3) }

    before do
      allow(RefreshUncollectedWorksCollection).to receive(:call)
      call
    end

    context 'when valid collection IDs are given' do
      let(:uncollected_works_collection_ids) { [uncollected_collection_1.id, uncollected_collection_2.id] }

      it 'calls RefreshUncollectedWorksCollection for each matching authority' do
        expect(RefreshUncollectedWorksCollection).to have_received(:call).with(authority_1)
        expect(RefreshUncollectedWorksCollection).to have_received(:call).with(authority_2)
        expect(RefreshUncollectedWorksCollection).to have_received(:call).exactly(2).times
      end
    end

    context 'when invalid collection IDs are given' do
      let(:uncollected_works_collection_ids) { [-1] }

      it 'does not call RefreshUncollectedWorksCollection' do
        expect(RefreshUncollectedWorksCollection).not_to have_received(:call)
      end
    end

    context 'when empty array is given' do
      let(:uncollected_works_collection_ids) { [] }

      it 'does not call RefreshUncollectedWorksCollection' do
        expect(RefreshUncollectedWorksCollection).not_to have_received(:call)
      end
    end
  end
end
