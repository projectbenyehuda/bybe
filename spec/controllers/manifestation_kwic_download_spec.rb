# frozen_string_literal: true

require 'rails_helper'

describe ManifestationController do
  describe '#download' do
    describe 'with format=kwic' do
      context 'for a manifestation' do
        let(:manifestation) do
          create(
            :manifestation,
            title: 'Test Work',
            markdown: "# Test Title\n\nThe quick brown fox jumps over the lazy dog.\n\nThe dog barks."
          )
        end

        subject { get :download, params: { id: manifestation.id, format: 'kwic' } }

        it 'returns a redirect' do
          subject
          expect(response).to have_http_status(:redirect)
        end

        it 'creates a downloadable with kwic format' do
          subject
          downloadable = manifestation.downloadables.find_by(doctype: 'kwic')
          expect(downloadable).to be_present
          expect(downloadable.stored_file).to be_attached
        end

        it 'generates concordance content' do
          subject
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

        subject { get :download, params: { id: manifestation.id, format: 'kwic' } }

        it 'reuses the existing downloadable' do
          subject
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

        subject do
          manifestation.touch # Update manifestation to make downloadable stale
          get :download, params: { id: manifestation.id, format: 'kwic' }
        end

        it 'creates a new downloadable' do
          subject
          downloadables = manifestation.downloadables.where(doctype: 'kwic')
          expect(downloadables.count).to eq(2)
          latest = downloadables.order(updated_at: :desc).first
          expect(latest.id).not_to eq(old_downloadable.id)
        end
      end

      context 'with Hebrew text' do
        let(:manifestation) do
          create(
            :manifestation,
            title: 'טקסט עברי',
            markdown: 'מפא"י היתה מפלגה פוליטית ישראלית. רמטכ"ל הוא ראש המטה הכללי של צה"ל.'
          )
        end

        subject { get :download, params: { id: manifestation.id, format: 'kwic' } }

        it 'preserves Hebrew acronyms' do
          subject
          downloadable = manifestation.downloadables.find_by(doctype: 'kwic')
          content = downloadable.stored_file.download
          expect(content).to include('מילה: מפא"י')
          expect(content).to include('מילה: רמטכ"ל')
          expect(content).to include('מילה: צה"ל')
        end
      end

      context 'with unrecognized format' do
        let(:manifestation) { create(:manifestation) }

        subject { get :download, params: { id: manifestation.id, format: 'invalid' } }

        it 'redirects with error' do
          subject
          expect(response).to have_http_status(:redirect)
          expect(flash[:error]).to be_present
        end
      end

      context 'when manifestation has only whitespace' do
        let(:empty_manifestation) { create(:manifestation, markdown: "   \n\n   ") }

        subject { get :download, params: { id: empty_manifestation.id, format: 'kwic' } }

        it 'generates concordance without errors' do
          subject
          downloadable = empty_manifestation.downloadables.find_by(doctype: 'kwic')
          expect(downloadable).to be_present
        end
      end
    end
  end
end
