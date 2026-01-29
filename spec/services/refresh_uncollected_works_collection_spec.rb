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

    context 'when called concurrently for the same authority' do
      let(:uncollected_works) { nil }

      it 'creates only one collection without orphans' do
        authority.reload

        # Count collections before concurrent execution
        initial_collection_count = Collection.where(collection_type: :uncollected).count

        # Simulate concurrent execution using threads
        # Use bypass strategy for Elasticsearch to avoid indexing errors in threads
        threads = 2.times.map do
          Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do
              Chewy.strategy(:bypass) do
                described_class.call(authority)
              end
            end
          end
        end

        threads.each(&:join)

        # Verify: Only 1 new collection created
        expect(Collection.where(collection_type: :uncollected).count).to eq(initial_collection_count + 1)

        # Verify: Authority is properly linked
        authority.reload
        expect(authority.uncollected_works_collection).to be_present
        expect(authority.uncollected_works_collection.collection_type).to eq('uncollected')

        # Verify: No orphaned collections exist (collections not linked to any authority)
        orphaned = Collection.where(collection_type: :uncollected)
                             .where.not(id: Authority.where.not(uncollected_works_collection_id: nil)
                                                     .select(:uncollected_works_collection_id))
        expect(orphaned.count).to eq(0)
      end

      it 'handles lock contention gracefully without raising errors' do
        authority.reload

        # Test that concurrent calls don't raise deadlock or other locking errors
        expect do
          threads = 3.times.map do
            Thread.new do
              ActiveRecord::Base.connection_pool.with_connection do
                Chewy.strategy(:bypass) do
                  described_class.call(authority)
                end
              end
            end
          end
          threads.each(&:join)
        end.not_to raise_error

        # Verify authority has a valid collection
        authority.reload
        expect(authority.uncollected_works_collection).to be_present
      end
    end
  end
end
