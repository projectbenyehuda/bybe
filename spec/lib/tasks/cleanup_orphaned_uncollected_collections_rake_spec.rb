# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'cleanup_orphaned_uncollected_collections', type: :task do
  before(:all) do
    Rake.application.rake_require 'tasks/cleanup_orphaned_uncollected_collections'
    Rake::Task.define_task(:environment)
  end

  let(:task) { Rake::Task['cleanup_orphaned_uncollected_collections'] }

  before do
    task.reenable
  end

  describe 'dry-run mode' do
    it 'identifies orphaned collections but does not delete them' do
      # Create orphaned collection by bypassing validations
      orphaned = create(:collection, collection_type: :other)
      orphaned.update_column(:collection_type, Collection.collection_types[:uncollected])

      initial_count = Collection.where(collection_type: :uncollected).count

      # Capture output
      expect do
        task.invoke
      end.to output(/Found 1 orphaned uncollected collection/).to_stdout

      # Verify no changes made
      expect(Collection.where(collection_type: :uncollected).count).to eq(initial_count)
      expect { orphaned.reload }.not_to raise_error
    end

    it 'outputs dry-run notice' do
      expect do
        task.invoke
      end.to output(/DRY-RUN mode/).to_stdout
    end
  end

  describe 'execute mode' do
    context 'with empty orphaned collection' do
      it 'deletes the empty orphaned collection' do
        # Create empty orphaned collection
        orphaned = create(:collection, collection_type: :other)
        orphaned.update_column(:collection_type, Collection.collection_types[:uncollected])
        orphaned_id = orphaned.id

        # Run task in execute mode
        task.invoke('execute')

        # Verify collection was deleted
        expect { Collection.find(orphaned_id) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'outputs deletion message' do
        orphaned = create(:collection, collection_type: :other)
        orphaned.update_column(:collection_type, Collection.collection_types[:uncollected])

        expect do
          task.invoke('execute')
        end.to output(/Empty collections deleted:\s+1/).to_stdout
      end
    end

    context 'with orphaned collection that can be linked' do
      it 'links the collection to the correct authority when identifiable' do
        # Create authority without uncollected collection
        authority = create(:authority, uncollected_works_collection: nil)

        # Create orphaned collection
        orphaned = create(:collection, collection_type: :other)
        orphaned.update_column(:collection_type, Collection.collection_types[:uncollected])

        # Add manifestation by this authority to the orphaned collection
        manifestation = create(:manifestation, author: authority)
        create(:collection_item, collection: orphaned, item: manifestation)

        # Run task
        task.invoke('execute')

        # Verify collection was linked
        authority.reload
        expect(authority.uncollected_works_collection_id).to eq(orphaned.id)
      end

      it 'outputs linking message' do
        authority = create(:authority, uncollected_works_collection: nil)
        orphaned = create(:collection, collection_type: :other)
        orphaned.update_column(:collection_type, Collection.collection_types[:uncollected])
        manifestation = create(:manifestation, author: authority)
        create(:collection_item, collection: orphaned, item: manifestation)

        expect do
          task.invoke('execute')
        end.to output(/Collections linked to authority:\s+1/).to_stdout
      end
    end

    context 'with orphaned collection when authority already has a collection' do
      it 'deletes the duplicate orphaned collection' do
        # Create authority with existing uncollected collection
        existing_collection = create(:collection, collection_type: :other)
        existing_collection.update_column(:collection_type, Collection.collection_types[:uncollected])
        authority = create(:authority, uncollected_works_collection: existing_collection)

        # Create orphaned duplicate collection
        orphaned = create(:collection, collection_type: :other)
        orphaned.update_column(:collection_type, Collection.collection_types[:uncollected])

        # Add manifestation by this authority to the orphaned collection
        manifestation = create(:manifestation, author: authority)
        create(:collection_item, collection: orphaned, item: manifestation)

        orphaned_id = orphaned.id

        # Run task
        task.invoke('execute')

        # Verify orphaned duplicate was deleted, existing collection remains
        expect { Collection.find(orphaned_id) }.to raise_error(ActiveRecord::RecordNotFound)
        expect { existing_collection.reload }.not_to raise_error
        authority.reload
        expect(authority.uncollected_works_collection_id).to eq(existing_collection.id)
      end
    end

    context 'with orphaned collection having items from multiple authorities' do
      it 'deletes the collection when authority cannot be determined' do
        # Create two authorities
        auth1 = create(:authority, uncollected_works_collection: nil)
        auth2 = create(:authority, uncollected_works_collection: nil)

        # Create orphaned collection with ambiguous ownership
        orphaned = create(:collection, collection_type: :other)
        orphaned.update_column(:collection_type, Collection.collection_types[:uncollected])

        # Add items from both authorities
        create(:collection_item, collection: orphaned, item: create(:manifestation, author: auth1))
        create(:collection_item, collection: orphaned, item: create(:manifestation, author: auth2))

        orphaned_id = orphaned.id

        # Run task
        expect do
          task.invoke('execute')
        end.to output(/WARNING.*Cannot determine owning authority/).to_stdout

        # Verify collection was deleted
        expect { Collection.find(orphaned_id) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'outputs deletion count' do
        auth1 = create(:authority)
        auth2 = create(:authority)
        orphaned = create(:collection, collection_type: :other)
        orphaned.update_column(:collection_type, Collection.collection_types[:uncollected])
        create(:collection_item, collection: orphaned, item: create(:manifestation, author: auth1))
        create(:collection_item, collection: orphaned, item: create(:manifestation, author: auth2))

        expect do
          task.invoke('execute')
        end.to output(/Unfixable collections deleted:\s+1/).to_stdout
      end
    end

    context 'with no orphaned collections' do
      it 'completes successfully with zero counts' do
        expect do
          task.invoke('execute')
        end.to output(/Found 0 orphaned uncollected collection/).to_stdout
      end
    end

    it 'outputs execution mode notice' do
      expect do
        task.invoke('execute')
      end.to output(/EXECUTE mode/).to_stdout
    end

    it 'outputs summary statistics' do
      expect do
        task.invoke('execute')
      end.to output(/Summary.*Orphaned collections found:/m).to_stdout
    end
  end

  describe 'idempotency' do
    it 'can be run multiple times safely' do
      # Create orphaned collection
      orphaned = create(:collection, collection_type: :other)
      orphaned.update_column(:collection_type, Collection.collection_types[:uncollected])

      # Run task twice
      task.invoke('execute')
      task.reenable
      expect do
        task.invoke('execute')
      end.not_to raise_error
    end
  end
end
