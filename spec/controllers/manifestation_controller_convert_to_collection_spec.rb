# frozen_string_literal: true

require 'rails_helper'

describe ManifestationController do
  describe '#convert_to_collection' do
    subject(:perform) { post :convert_to_collection, params: { id: manifestation.id, collection_type: 'volume' } }

    let(:manifestation) { create(:manifestation, title: 'Poems', markdown: "## One\nFirst\n## Two\nSecond\n") }

    context 'when the editor holds the batch_editing bit' do
      before { session[:user_id] = create_batch_editor.id }

      it 'converts the text and redirects to the new collection' do
        expect { perform }.to change(Collection, :count).by(1)
        collection = Collection.last
        expect(collection).to be_volume
        expect(response).to redirect_to(collection_path(collection))
        expect(flash[:notice]).to eq(I18n.t(:convert_to_collection_succeeded))
      end

      context 'when the text cannot be split' do
        let(:manifestation) { create(:manifestation, markdown: "No headings here\n") }

        it 'reports the error and returns to the show page' do
          expect { perform }.not_to change(Collection, :count)
          expect(response).to redirect_to(manifestation_show_path(manifestation.id))
          expect(flash[:alert]).to eq(
            I18n.t(:convert_to_collection_failed, error: I18n.t(:convert_to_collection_too_few_headings))
          )
        end
      end
    end

    context 'when the editor holds edit_catalog but not batch_editing' do
      before { session[:user_id] = create(:user, :edit_catalog).id }

      it 'refuses' do
        expect { perform }.not_to change(Collection, :count)
        expect(response).to be_redirect
        expect(manifestation.reload.title).to eq('Poems')
      end
    end
  end
end
