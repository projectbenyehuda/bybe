# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'KWIC Concordance Downloads' do
  describe 'GET /download/:id with format=kwic' do
    context 'for a manifestation' do
      let(:manifestation) do
        create(
          :manifestation,
          title: 'Test Work',
          markdown: "# Test Title\n\nThe quick brown fox jumps over the lazy dog.\n\nThe dog barks."
        )
      end

      before do
        get manifestation_download_path(manifestation), params: { format: 'kwic' }
      end

      it 'returns a successful response' do
        expect(response).to have_http_status(:redirect)
      end

      it 'creates a downloadable with kwic format' do
        downloadable = manifestation.downloadables.find_by(doctype: 'kwic')
        expect(downloadable).to be_present
        expect(downloadable.stored_file).to be_attached
      end

      it 'generates concordance content' do
        downloadable = manifestation.downloadables.find_by(doctype: 'kwic')
        content = downloadable.stored_file.download
        expect(content).to include('קונקורדנציה בתבנית KWIC')
        expect(content).to include('מילה: The')
        expect(content).to include('מילה: quick')
        expect(content).to include('[Test Work, פסקה')
      end
    end

    context 'when downloadable already exists and is fresh' do
      let(:manifestation) { create(:manifestation, markdown: 'Simple text.') }
      let!(:existing_downloadable) do
        create(:downloadable, :with_file, object: manifestation, doctype: :kwic)
      end

      before do
        get manifestation_download_path(manifestation), params: { format: 'kwic' }
      end

      it 'reuses the existing downloadable' do
        expect(manifestation.downloadables.where(doctype: 'kwic').count).to eq(1)
        expect(manifestation.downloadables.find_by(doctype: 'kwic').id).to eq(existing_downloadable.id)
      end
    end

    context 'when downloadable exists but is outdated' do
      let(:manifestation) { create(:manifestation, markdown: 'Old text.') }
      let!(:old_downloadable) do
        dl = create(:downloadable, :with_file, object: manifestation, doctype: :kwic)
        dl.update_column(:updated_at, 2.days.ago)
        dl
      end

      before do
        manifestation.touch # Update manifestation to make downloadable stale
        get manifestation_download_path(manifestation), params: { format: 'kwic' }
      end

      it 'creates a new downloadable' do
        downloadables = manifestation.downloadables.where(doctype: 'kwic')
        expect(downloadables.count).to eq(2)
        latest = downloadables.order(updated_at: :desc).first
        expect(latest.id).not_to eq(old_downloadable.id)
      end
    end
  end

  describe 'POST /collections/:collection_id/download with format=kwic' do
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

      before do
        create(:collection_item, collection: collection, item: manifestation1)
        create(:collection_item, collection: collection, item: manifestation2)
        post collection_download_path(collection), params: { format: 'kwic' }
      end

      it 'returns a successful response' do
        expect(response).to have_http_status(:redirect)
      end

      it 'creates a downloadable with kwic format' do
        downloadable = collection.downloadables.find_by(doctype: 'kwic')
        expect(downloadable).to be_present
        expect(downloadable.stored_file).to be_attached
      end

      it 'generates concordance content from all manifestations' do
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

      before do
        post collection_download_path(collection), params: { format: 'kwic' }
      end

      it 'redirects with error' do
        expect(response).to have_http_status(:redirect)
        expect(flash[:error]).to be_present
      end

      it 'does not create a downloadable' do
        expect(collection.downloadables).to be_empty
      end
    end
  end

  describe 'KWIC format with Hebrew text' do
    let(:manifestation) do
      create(
        :manifestation,
        title: 'טקסט עברי',
        markdown: 'מפא"י היתה מפלגה פוליטית ישראלית. רמטכ"ל הוא ראש המטה הכללי של צה"ל.'
      )
    end

    before do
      get manifestation_download_path(manifestation), params: { format: 'kwic' }
    end

    it 'preserves Hebrew acronyms' do
      downloadable = manifestation.downloadables.find_by(doctype: 'kwic')
      content = downloadable.stored_file.download
      expect(content).to include('מילה: מפא"י')
      expect(content).to include('מילה: רמטכ"ל')
      expect(content).to include('מילה: צה"ל')
    end
  end

  describe 'downloading with unrecognized format' do
    let(:manifestation) { create(:manifestation) }

    before do
      get manifestation_download_path(manifestation), params: { format: 'invalid' }
    end

    it 'redirects with error' do
      expect(response).to have_http_status(:redirect)
      expect(flash[:error]).to be_present
    end
  end
end
