# frozen_string_literal: true

require 'rails_helper'

describe AnthologiesController do
  describe '#download' do
    describe 'with format=kwic' do
      let(:user) { create(:user) }
      let(:anthology) { create(:anthology, user: user, access: :pub, title: 'Test Anthology') }
      let(:manifestation1) do
        create(
          :manifestation,
          title: 'First Text',
          markdown: 'The quick brown fox.'
        )
      end
      let(:manifestation2) do
        create(
          :manifestation,
          title: 'Second Text',
          markdown: 'The brown bear.'
        )
      end

      subject do
        create(:anthology_text, anthology: anthology, manifestation: manifestation1)
        create(:anthology_text, anthology: anthology, manifestation: manifestation2)
        post :download, params: { id: anthology.id, format: 'kwic' }
      end

      it 'returns a redirect' do
        subject
        expect(response).to have_http_status(:redirect)
      end

      it 'creates a downloadable with kwic format' do
        subject
        downloadable = anthology.downloadables.find_by(doctype: 'kwic')
        expect(downloadable).to be_present
        expect(downloadable.stored_file).to be_attached
      end

      it 'generates concordance content from all anthology texts' do
        subject
        downloadable = anthology.downloadables.find_by(doctype: 'kwic')
        content = downloadable.stored_file.download
        expect(content).to include('קונקורדנציה בתבנית KWIC')
        expect(content).to include('מילה: brown')
        # Should show instances from both texts
        expect(content).to include('[First Text, פסקה')
        expect(content).to include('[Second Text, פסקה')
      end
    end
  end
end
