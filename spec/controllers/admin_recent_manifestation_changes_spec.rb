# frozen_string_literal: true

require 'rails_helper'

describe AdminController do
  let(:user) { create(:user, editor: true) }
  let(:manifestation1) { create(:manifestation, markdown: 'Content 1') }
  let(:manifestation2) { create(:manifestation, markdown: 'Content 2') }

  before do
    # Create editor bit for user
    ListItem.create!(listkey: 'edit_catalog', item: user)
    PaperTrail.request.whodunnit = user.id.to_s
  end

  describe '#recent_manifestation_changes' do
    context 'when user is not an editor' do
      let(:non_editor_user) { create(:user, editor: false) }

      before do
        session[:user_id] = non_editor_user.id
      end

      it 'redirects to home page' do
        get :recent_manifestation_changes
        expect(response).to redirect_to('/')
      end
    end

    context 'when user is an editor' do
      before do
        session[:user_id] = user.id
      end

      it 'shows all recent manifestation changes' do
        # Create some versions
        manifestation1.update!(markdown: 'Updated content 1')
        manifestation2.update!(markdown: 'Updated content 2')

        get :recent_manifestation_changes

        expect(response).to be_successful
        expect(assigns(:versions)).not_to be_empty
        versions = assigns(:versions)
        expect(versions.map(&:item_id)).to include(manifestation1.id, manifestation2.id)
      end

      it 'filters by editor when editor param is provided' do
        other_user = create(:user, editor: true)
        ListItem.create!(listkey: 'edit_catalog', item: other_user)

        # Update as first user
        manifestation1.update!(markdown: 'Updated by user 1')

        # Update as second user
        PaperTrail.request.whodunnit = other_user.id.to_s
        manifestation2.update!(markdown: 'Updated by user 2')

        get :recent_manifestation_changes, params: { editor: user.id.to_s }

        versions = assigns(:versions)
        expect(versions.all? { |v| v.whodunnit == user.id.to_s }).to be true
      end

      it 'pre-loads manifestations' do
        manifestation1.update!(markdown: 'Updated')

        get :recent_manifestation_changes

        manifestations = assigns(:manifestations)
        expect(manifestations).to be_a(Hash)
        expect(manifestations[manifestation1.id]).to eq(manifestation1)
      end

      it 'calculates markdown changes correctly' do
        # Update markdown - should be marked as markdown change
        manifestation1.update!(markdown: 'Changed markdown')
        markdown_version_id = manifestation1.versions.last.id

        # Update title only - should NOT be marked as markdown change
        manifestation1.update!(title: 'Changed title only')
        title_version_id = manifestation1.versions.last.id

        get :recent_manifestation_changes

        markdown_changes = assigns(:markdown_changes)
        expect(markdown_changes).to be_a(Hash)
        expect(markdown_changes[markdown_version_id]).to be(true)
        expect(markdown_changes[title_version_id]).to be(false)
      end

      it 'requires edit_catalog bit' do
        # Remove the edit_catalog bit
        ListItem.where(listkey: 'edit_catalog', item: user).delete_all

        get :recent_manifestation_changes

        expect(response).to redirect_to('/')
      end
    end
  end
end
