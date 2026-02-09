# frozen_string_literal: true

require 'rails_helper'

describe ManifestationController do
  let(:user) { create(:user, editor: true) }
  let(:manifestation) { create(:manifestation, markdown: 'Original content') }

  before do
    # Create editor bit for user
    ListItem.create!(listkey: 'edit_catalog', item: user)
    session[:user_id] = user.id
    PaperTrail.request.whodunnit = user.id.to_s
  end

  describe '#versions' do
    context 'when user is not an editor' do
      let(:non_editor_user) { create(:user, editor: false) }

      before do
        session[:user_id] = non_editor_user.id
      end

      it 'redirects to home page' do
        get :versions, params: { id: manifestation.id }
        expect(response).to redirect_to('/')
      end
    end

    context 'when user is an editor with edit_catalog bit' do
      it 'shows version history' do
        # Create a version by updating the manifestation
        manifestation.update!(markdown: 'Updated content', title: 'Updated Title')

        get :versions, params: { id: manifestation.id }

        expect(response).to be_successful
        expect(assigns(:m)).to eq(manifestation)
        expect(assigns(:versions)).not_to be_empty
      end

      it 'marks versions with markdown changes' do
        manifestation.update!(markdown: 'Changed markdown')
        manifestation.update!(title: 'Changed title only')

        get :versions, params: { id: manifestation.id }

        markdown_changes = assigns(:markdown_changes)
        expect(markdown_changes).to be_a(Hash)
      end
    end
  end

  describe '#version_diff' do
    before do
      manifestation.update!(markdown: 'New content')
    end

    context 'when user is not an editor' do
      let(:non_editor_user) { create(:user, editor: false) }

      before do
        session[:user_id] = non_editor_user.id
      end

      it 'redirects to home page' do
        version = manifestation.versions.last
        get :version_diff, params: { id: manifestation.id, version_id: version.id }
        expect(response).to redirect_to('/')
      end
    end

    context 'when user is an editor' do
      it 'shows diff between versions' do
        version = manifestation.versions.last

        get :version_diff, params: { id: manifestation.id, version_id: version.id }

        expect(response).to be_successful
        expect(assigns(:current_markdown)).to eq('New content')
        expect(assigns(:previous_markdown)).to eq('Original content')
      end
    end
  end

  describe '#restore_version' do
    let!(:old_version) do
      manifestation.update!(markdown: 'Version 2 content')
      manifestation.update!(markdown: 'Version 3 content')
      manifestation.versions.where(id: ...manifestation.versions.last.id).order(created_at: :desc).first
    end

    context 'when user is not an editor' do
      let(:non_editor_user) { create(:user, editor: false) }

      before do
        session[:user_id] = non_editor_user.id
      end

      it 'redirects to home page' do
        post :restore_version, params: { id: manifestation.id, version_id: old_version.id }
        expect(response).to redirect_to('/')
      end
    end

    context 'when user is an editor' do
      it 'restores the old version' do
        expect do
          post :restore_version, params: { id: manifestation.id, version_id: old_version.id }
        end.to change { manifestation.reload.markdown }.to('Version 2 content')

        expect(response).to redirect_to(manifestation_versions_path(manifestation))
        expect(flash[:notice]).to eq(I18n.t(:version_restored))
      end

      it 'creates a new version when restoring' do
        initial_version_count = manifestation.versions.count

        post :restore_version, params: { id: manifestation.id, version_id: old_version.id }

        expect(manifestation.versions.count).to be > initial_version_count
      end
    end
  end
end
