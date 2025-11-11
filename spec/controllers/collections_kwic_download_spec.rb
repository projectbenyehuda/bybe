# frozen_string_literal: true

require 'rails_helper'

describe CollectionsController do
  describe '#download' do
    describe 'with format=kwic' do
      context 'for a collection with multiple manifestations' do
        subject do
          create(:collection_item, collection: collection, item: manifestation1)
          create(:collection_item, collection: collection, item: manifestation2)
          post :download, params: { collection_id: collection.id, format: 'kwic' }
        end

        let(:collection) { create(:collection, title: 'Test Collection') }
        let(:manifestation1) do
          create(
            :manifestation,
            title: 'First Work',
            markdown: 'The quick brown fox.'
          )
        end
        let(:manifestation2) do
          create(
            :manifestation,
            title: 'Second Work',
            markdown: 'The brown bear.'
          )
        end

        it 'returns a redirect' do
          subject
          expect(response).to have_http_status(:redirect)
        end

        it 'triggers async job and shows notice message' do
          subject
          expect(flash[:notice]).to eq(I18n.t(:kwic_being_generated))
          expect(response).to redirect_to(collection)
        end

        it 'creates a downloadable with kwic format after job runs' do
          create(:collection_item, collection: collection, item: manifestation1)
          create(:collection_item, collection: collection, item: manifestation2)
          
          # Execute the job synchronously
          GenerateKwicConcordanceJob.new.perform('Collection', collection.id)
          
          downloadable = collection.downloadables.find_by(doctype: 'kwic')
          expect(downloadable).to be_present
          expect(downloadable.stored_file).to be_attached
        end

        it 'generates concordance content from all manifestations after job runs' do
          create(:collection_item, collection: collection, item: manifestation1)
          create(:collection_item, collection: collection, item: manifestation2)
          
          # Execute the job synchronously
          GenerateKwicConcordanceJob.new.perform('Collection', collection.id)
          
          downloadable = collection.downloadables.find_by(doctype: 'kwic')
          content = downloadable.stored_file.download.force_encoding('UTF-8')
          expect(content).to include('קונקורדנציה בתבנית KWIC')
          expect(content).to include('מילה: brown')
          # Should show instances from both texts
          expect(content).to include('[First Work, פסקה')
          expect(content).to include('[Second Work, פסקה')
        end

        it 'returns downloadable immediately when fresh downloadable exists' do
          create(:collection_item, collection: collection, item: manifestation1)
          create(:collection_item, collection: collection, item: manifestation2)
          
          # Make everything older first
          collection.update_column(:updated_at, 10.minutes.ago)
          collection.collection_items.each { |ci| ci.update_column(:updated_at, 10.minutes.ago) }
          manifestation1.update_column(:updated_at, 10.minutes.ago)
          manifestation2.update_column(:updated_at, 10.minutes.ago)
          
          # Pre-generate the downloadable (this will be newer than everything else)
          GenerateKwicConcordanceJob.new.perform('Collection', collection.id)
          
          collection.reload
          
          # Now request download
          post :download, params: { collection_id: collection.id, format: 'kwic' }
          
          expect(response).to have_http_status(:redirect)
          expect(flash[:notice]).to be_nil
          expect(flash[:error]).to be_nil
          downloadable = collection.downloadables.find_by(doctype: 'kwic')
          expect(downloadable).to be_present
        end
      end

      context 'when collection has suppress_download_and_print enabled' do
        subject { post :download, params: { collection_id: collection.id, format: 'kwic' } }

        let(:collection) { create(:collection, suppress_download_and_print: true) }

        it 'redirects with error' do
          subject
          expect(response).to have_http_status(:redirect)
          expect(flash[:error]).to be_present
        end

        it 'does not create a downloadable' do
          subject
          expect(collection.downloadables).to be_empty
        end
      end

      context 'when collection is empty' do
        subject { post :download, params: { collection_id: empty_collection.id, format: 'kwic' } }

        let(:empty_collection) { create(:collection, title: 'Empty Collection') }

        it 'returns a redirect' do
          subject
          expect(response).to have_http_status(:redirect)
        end

        it 'creates a downloadable with only header after job runs' do
          # Execute the job synchronously
          GenerateKwicConcordanceJob.new.perform('Collection', empty_collection.id)
          
          downloadable = empty_collection.downloadables.find_by(doctype: 'kwic')
          expect(downloadable).to be_present
          content = downloadable.stored_file.download.force_encoding('UTF-8')
          expect(content).to include('קונקורדנציה בתבנית KWIC')
          expect(content).not_to include('מילה:')
        end
      end
    end
  end
end
