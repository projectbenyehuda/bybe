# frozen_string_literal: true

require 'rails_helper'

describe CollectionsController do
  describe '#download' do
    describe 'with format=kwic' do
      context 'for a collection with multiple manifestations' do
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

        subject do
          create(:collection_item, collection: collection, item: manifestation1)
          create(:collection_item, collection: collection, item: manifestation2)
          post :download, params: { collection_id: collection.id, format: 'kwic' }
        end

        it 'returns a redirect' do
          subject
          expect(response).to have_http_status(:redirect)
        end

        it 'creates a downloadable with kwic format' do
          subject
          downloadable = collection.downloadables.find_by(doctype: 'kwic')
          expect(downloadable).to be_present
          expect(downloadable.stored_file).to be_attached
        end

        it 'generates concordance content from all manifestations' do
          subject
          downloadable = collection.downloadables.find_by(doctype: 'kwic')
          content = downloadable.stored_file.download
          expect(content).to include('קונקורדנציה בתבנית KWIC')
          expect(content).to include('מילה: brown')
          # Should show instances from both texts
          expect(content).to include('[First Work, פסקה')
          expect(content).to include('[Second Work, פסקה')
        end
      end

      context 'when collection has suppress_download_and_print enabled' do
        let(:collection) { create(:collection, suppress_download_and_print: true) }

        subject { post :download, params: { collection_id: collection.id, format: 'kwic' } }

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
        let(:empty_collection) { create(:collection, title: 'Empty Collection') }

        subject { post :download, params: { collection_id: empty_collection.id, format: 'kwic' } }

        it 'returns a redirect' do
          subject
          expect(response).to have_http_status(:redirect)
        end

        it 'creates a downloadable with only header' do
          subject
          downloadable = empty_collection.downloadables.find_by(doctype: 'kwic')
          expect(downloadable).to be_present
          content = downloadable.stored_file.download
          expect(content).to include('קונקורדנציה בתבנית KWIC')
          expect(content).not_to include('מילה:')
        end
      end
    end
  end
end
