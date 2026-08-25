# frozen_string_literal: true

require 'rails_helper'

describe ManifestationController do
  let(:editor) { create(:user, :deletions) }
  let(:manifestation) { create(:manifestation) }
  let(:target) { create(:manifestation) }

  describe '#soft_delete' do
    subject(:perform) { post :soft_delete, params: params }

    let(:params) { { id: manifestation.id, soft_redirect_id: target.id } }

    before { session[:user_id] = editor.id }

    it 'soft-deletes the manifestation and redirects back to its show page' do
      perform
      expect(response).to redirect_to(manifestation_show_path(manifestation.id))
      expect(flash[:notice]).to eq(I18n.t(:soft_delete_succeeded, id: target.id.to_s))
      manifestation.reload
      expect(manifestation).to be_deprecated
      expect(manifestation.soft_redirect).to eq(target.id)
    end

    context 'when only the autocomplete field is filled in' do
      let(:params) { { id: manifestation.id, soft_redirect_autocomplete_id: target.id } }

      it 'uses it' do
        perform
        expect(manifestation.reload.soft_redirect).to eq(target.id)
      end
    end

    context 'when both fields are filled in' do
      let(:other) { create(:manifestation) }
      let(:params) do
        { id: manifestation.id, soft_redirect_id: target.id, soft_redirect_autocomplete_id: other.id }
      end

      it 'lets the literal id win' do
        perform
        expect(manifestation.reload.soft_redirect).to eq(target.id)
      end
    end

    context 'when the autocomplete field is blank and the literal id is filled in' do
      let(:params) { { id: manifestation.id, soft_redirect_id: target.id, soft_redirect_autocomplete_id: '' } }

      it 'uses the literal id' do
        perform
        expect(manifestation.reload.soft_redirect).to eq(target.id)
      end
    end

    context 'when neither field identifies a manifestation' do
      let(:params) { { id: manifestation.id, soft_redirect_id: '', soft_redirect_autocomplete_id: '' } }

      it 'reports the failure and changes nothing' do
        perform
        expect(flash[:alert]).to eq(I18n.t(:soft_delete_failed, error: I18n.t(:manifestation_not_found)))
        expect(manifestation.reload).to be_published
      end
    end

    context 'when the target is already soft-deleted' do
      let(:target) { create(:manifestation, status: :deprecated) }

      it 'refuses' do
        perform
        expect(flash[:alert]).to eq(I18n.t(:soft_delete_failed, error: I18n.t(:soft_delete_target_deprecated)))
        expect(manifestation.reload).to be_published
      end
    end

    context 'when the target is not published' do
      let(:target) { create(:manifestation, status: :unpublished) }

      it 'refuses' do
        perform
        expect(flash[:alert]).to eq(I18n.t(:soft_delete_failed, error: I18n.t(:soft_delete_target_not_published)))
        expect(manifestation.reload).to be_published
      end
    end

    context 'when nobody is logged in' do
      before { session.delete(:user_id) }

      it 'refuses and leaves the manifestation published' do
        perform
        expect(response).to redirect_to('/')
        expect(manifestation.reload).to be_published
      end
    end

    context 'when the user is an editor without the deletions bit' do
      let(:editor) { create(:user, editor: true) }

      it 'refuses' do
        perform
        expect(manifestation.reload).to be_published
      end
    end

    context 'when the user is an edit_catalog editor without the deletions bit' do
      let(:editor) { create(:user, :edit_catalog) }

      it 'refuses' do
        perform
        expect(response).to redirect_to('/')
        expect(manifestation.reload).to be_published
      end
    end
  end

  describe '#undo_soft_delete' do
    subject(:perform) { post :undo_soft_delete, params: { id: manifestation.id } }

    let(:tagging) { create(:tagging, taggable: manifestation) }

    before do
      session[:user_id] = editor.id
      tagging # referenced here so that it exists before the soft-deletion, which moves it
      SoftDeleteManifestation.call(manifestation, target)
    end

    it 'republishes the manifestation and redirects back to its show page' do
      perform
      expect(response).to redirect_to(manifestation_show_path(manifestation.id))
      expect(flash[:notice]).to eq(I18n.t(:undo_soft_delete_succeeded))
      expect(manifestation.reload).to be_published
    end

    it 'stops redirecting readers to the former target' do
      perform
      get :read, params: { id: manifestation.id }
      expect(response).to be_successful
    end

    # The moved associations cannot be told apart from ones the target already had, so undoing
    # restores visibility only -- see the note on ManifestationController#undo_soft_delete.
    it 'leaves the tagging the soft-deletion moved on the target' do
      expect(tagging.reload.taggable).to eq(target)
      perform
      expect(tagging.reload.taggable).to eq(target)
    end

    context 'when the manifestation was not soft-deleted' do
      before { manifestation.update!(status: :published) }

      it 'refuses and says so' do
        perform
        expect(flash[:alert]).to eq(I18n.t(:undo_soft_delete_not_deprecated))
        expect(manifestation.reload).to be_published
      end
    end

    context 'when the manifestation is unpublished rather than soft-deleted' do
      before { manifestation.update!(status: :unpublished) }

      it 'does not publish it' do
        perform
        expect(manifestation.reload).to be_unpublished
      end
    end

    context 'when the user is an editor without the deletions bit' do
      let(:editor) { create(:user, editor: true) }

      it 'refuses and leaves the manifestation soft-deleted' do
        perform
        expect(response).to redirect_to('/')
        expect(manifestation.reload).to be_deprecated
      end
    end
  end

  describe '#read of a soft-deleted manifestation' do
    before { SoftDeleteManifestation.call(manifestation, target) }

    it 'redirects an anonymous reader to the redirect target' do
      get :read, params: { id: manifestation.id }
      expect(response).to redirect_to(manifestation_path(target.id))
    end

    it 'redirects an editor too' do
      session[:user_id] = editor.id
      get :read, params: { id: manifestation.id }
      expect(response).to redirect_to(manifestation_path(target.id))
    end

    it 'follows a chain when the target is soft-deleted later on' do
      final = create(:manifestation)
      SoftDeleteManifestation.call(target, final)
      get :read, params: { id: manifestation.id }
      expect(response).to redirect_to(manifestation_path(final.id))
    end

    it 'falls back to the "not available" treatment when the chain leads nowhere' do
      manifestation.update!(soft_redirect: nil)
      get :read, params: { id: manifestation.id }
      expect(response).to redirect_to('/')
      expect(flash[:notice]).to eq(I18n.t(:work_not_available))
    end

    it 'falls back to the "not available" treatment on a cycle' do
      target.update!(status: :deprecated, soft_redirect: manifestation.id)
      get :read, params: { id: manifestation.id }
      expect(response).to redirect_to('/')
    end

    it 'still renders a live manifestation normally' do
      get :read, params: { id: target.id }
      expect(response).to be_successful
    end
  end
end
