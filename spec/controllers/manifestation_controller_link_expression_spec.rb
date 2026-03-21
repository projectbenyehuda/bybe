# frozen_string_literal: true

require 'rails_helper'

describe ManifestationController do
  let(:editor) { create(:user, :edit_catalog) }

  before { session[:user_id] = editor.id }

  describe '#preview_link_expression' do
    let(:manifestation) { create(:manifestation) }
    let(:other_manifestation) { create(:manifestation) }

    context 'when other_manifestation_id is valid' do
      subject(:response) do
        get :preview_link_expression, params: { id: manifestation.id, other_manifestation_id: other_manifestation.id }
      end

      it { is_expected.to be_successful }

      it 'renders the preview partial' do
        response
        expect(response.body).to include(other_manifestation.expression.work.title)
      end
    end

    context 'when other_manifestation_id does not exist' do
      subject(:response) do
        get :preview_link_expression, params: { id: manifestation.id, other_manifestation_id: 0 }
      end

      it { is_expected.to be_successful }

      it 'renders an error message' do
        response
        expect(response.body).to include(I18n.t(:manifestation_not_found))
      end
    end

    context 'when not an editor' do
      subject(:response) do
        get :preview_link_expression, params: { id: manifestation.id, other_manifestation_id: other_manifestation.id }
      end

      before { session.delete(:user_id) }

      it { is_expected.to redirect_to('/') }
    end
  end

  describe '#link_expression' do
    subject(:perform) do
      post :link_expression, params: { id: manifestation_a.id, other_manifestation_id: manifestation_b.id }
    end

    let(:shared_author) { create(:authority) }
    let(:manifestation_a) { create(:manifestation, author: shared_author) }
    let(:manifestation_b) { create(:manifestation, author: shared_author) }
    let(:work_a) { manifestation_a.expression.work }
    let(:work_b) { manifestation_b.expression.work }

    it 'redirects to edit_metadata' do
      perform
      expect(response).to redirect_to(manifestation_edit_metadata_path(id: manifestation_a.id))
    end

    it 'merges the works' do
      older_id = [work_a.id, work_b.id].min
      perform
      expect(Work.exists?(older_id)).to be(true)
      expect(manifestation_a.expression.reload.work_id).to eq(older_id)
      expect(manifestation_b.expression.reload.work_id).to eq(older_id)
    end

    it 'sets a success flash notice' do
      perform
      expect(flash[:notice]).to eq(I18n.t(:expressions_linked_successfully))
    end

    context 'when other_manifestation_id does not exist' do
      subject(:perform) do
        post :link_expression, params: { id: manifestation_a.id, other_manifestation_id: 0 }
      end

      it 'redirects to edit_metadata' do
        perform
        expect(response).to redirect_to(manifestation_edit_metadata_path(id: manifestation_a.id))
      end

      it 'sets an alert flash' do
        perform
        expect(flash[:alert]).to eq(I18n.t(:manifestation_not_found))
      end

      it 'does not change the work' do
        expect { perform }.not_to(change { manifestation_a.expression.reload.work_id })
      end
    end

    context 'when both manifestations belong to the same work' do
      let(:expression_b) { create(:expression, work: work_a, intellectual_property: :public_domain) }
      let(:manifestation_b) { create(:manifestation, expression: expression_b) }

      it 'redirects to edit_metadata with already-linked notice' do
        perform
        expect(response).to redirect_to(manifestation_edit_metadata_path(id: manifestation_a.id))
        expect(flash[:notice]).to eq(I18n.t(:expressions_already_linked))
      end
    end

    context 'when not an editor' do
      before { session.delete(:user_id) }

      it { is_expected.to redirect_to('/') }
    end
  end
end
