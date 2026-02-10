# frozen_string_literal: true

require 'rails_helper'

describe AdminController do
  include ActiveSupport::Testing::TimeHelpers

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
        # Create manifestations and then travel to next day before updating
        # (so changes aren't filtered out as same-day noise)
        m1 = manifestation1
        m2 = manifestation2

        travel 1.day do
          m1.update!(markdown: 'Updated content 1')
          m2.update!(markdown: 'Updated content 2')

          get :recent_manifestation_changes

          expect(response).to be_successful
          expect(assigns(:versions)).not_to be_empty
          versions = assigns(:versions)
          expect(versions.map(&:item_id)).to include(m1.id, m2.id)
        end
      end

      it 'filters by editor when editor param is provided' do
        other_user = create(:user, editor: true)
        ListItem.create!(listkey: 'edit_catalog', item: other_user)

        m1 = manifestation1
        m2 = manifestation2

        travel 1.day do
          # Update as first user
          m1.update!(markdown: 'Updated by user 1')

          # Update as second user
          PaperTrail.request.whodunnit = other_user.id.to_s
          m2.update!(markdown: 'Updated by user 2')

          get :recent_manifestation_changes, params: { editor: user.id.to_s }

          versions = assigns(:versions)
          expect(versions.all? { |v| v.whodunnit == user.id.to_s }).to be true
        end
      end

      it 'pre-loads manifestations' do
        m1 = manifestation1

        travel 1.day do
          m1.update!(markdown: 'Updated')

          get :recent_manifestation_changes

          manifestations = assigns(:manifestations)
          expect(manifestations).to be_a(Hash)
          expect(manifestations[m1.id]).to eq(m1)
        end
      end

      it 'calculates markdown changes correctly' do
        m1 = manifestation1

        travel 1.day do
          # Update markdown - should be marked as markdown change
          m1.update!(markdown: 'Changed markdown')
          markdown_version_id = m1.versions.last.id

          # Update title only - should NOT be marked as markdown change
          m1.update!(title: 'Changed title only')
          title_version_id = m1.versions.last.id

          get :recent_manifestation_changes

          markdown_changes = assigns(:markdown_changes)
          expect(markdown_changes).to be_a(Hash)
          expect(markdown_changes[markdown_version_id]).to be(true)
          expect(markdown_changes[title_version_id]).to be(false)
        end
      end

      it 'requires edit_catalog bit' do
        # Remove the edit_catalog bit
        ListItem.where(listkey: 'edit_catalog', item: user).delete_all

        get :recent_manifestation_changes

        expect(response).to redirect_to('/')
      end

      it 'suppresses changes made on the same day as manifestation creation' do
        # Create a manifestation
        fresh_manifestation = create(:manifestation, markdown: 'Initial content')

        # Make a change on the same day (should be suppressed)
        fresh_manifestation.update!(markdown: 'Same-day change')
        same_day_version_id = fresh_manifestation.versions.last.id

        # Move to next day and make another change (should NOT be suppressed)
        travel 1.day do
          fresh_manifestation.update!(markdown: 'Next-day change')
          next_day_version_id = fresh_manifestation.versions.last.id

          get :recent_manifestation_changes

          versions = assigns(:versions)
          version_ids = versions.map(&:id)

          # Same-day change should be filtered out
          expect(version_ids).not_to include(same_day_version_id)
          # Next-day change should be included
          expect(version_ids).to include(next_day_version_id)
        end
      end
    end
  end
end
