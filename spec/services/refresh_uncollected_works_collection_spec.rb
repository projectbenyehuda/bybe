# frozen_string_literal: true

require 'rails_helper'

describe RefreshUncollectedWorksCollection do
  let!(:authority) { create(:authority, uncollected_works_collection: uncollected_works) }
  let!(:other_uncollected_works) { create(:collection, :uncollected) }
  let!(:other_authority) { create(:authority, uncollected_works_collection: other_uncollected_works) }

  # Those items are not included to any collection so should get into uncollected works collection
  let!(:uncollected_original_works) do
    create_list(
      :manifestation,
      3,
      author: authority,
      orig_lang: :de,
      translator: other_authority
    )
  end

  # Those items belongs to uncollected works collection but for different authority, so it should be included too
  let!(:uncollected_translated_works) do
    create_list(
      :manifestation,
      2,
      author: other_authority,
      orig_lang: :en,
      translator: authority,
      collections: [other_uncollected_works]
    )
  end

  let(:uncollected_manifestation_ids) do
    uncollected_original_works.map(&:id) + uncollected_translated_works.map(&:id)
  end

  let!(:volume) { create(:collection, collection_type: :volume) }

  # This work is included in volume collection, so should not be included in uncollected works collection
  let!(:collected_work) { create(:manifestation, collections: [volume], author: authority) }

  describe '.call' do
    subject(:call) { described_class.call(authority) }

    context 'when there is no uncollected works collection' do
      let(:uncollected_works) { nil }

      it 'creates collection and adds there uncollected works' do
        expect { call }.to change(Collection, :count).by(1)
        authority.reload
        collection = authority.uncollected_works_collection
        expect(collection).not_to be_nil
        expect(collection.collection_type).to eq 'uncollected'
        expect(collection.collection_items.map(&:item_id)).to match_array(uncollected_manifestation_ids)
      end
    end

    context 'when there is an uncollected works collection and it has items to be removed' do
      let(:uncollected_works) { create(:collection, :uncollected) }

      # this item should be removed from collection
      let!(:already_collected_manifestation) do
        create(
          :manifestation,
          author: authority,
          collections: [uncollected_works, volume]
        )
      end

      it 'adds missing items to collection and removes items included in other collections' do
        expect { call }.to not_change(Collection, :count)
        collection = authority.uncollected_works_collection.reload
        expect(collection.collection_items.map(&:item_id)).to match_array(uncollected_manifestation_ids)
      end
    end
  end
end
