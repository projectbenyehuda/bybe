# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::SavedSelections', type: :request do
  let(:owner)      { login_as_batch_editor }
  let(:other_user) { create(:user, editor: true) }

  def make_selection(user:, shared: false)
    SavedSelection.create!(name: 'Test Selection', user: user,
                           delete_after: 90.days.from_now.to_date, shared: shared)
  end

  before { owner } # ensure login_as_catalog_editor runs and stubs current_user

  # ---------------------------------------------------------------------------
  # DELETE /admin/saved_selections/:id
  # ---------------------------------------------------------------------------
  describe 'DELETE /admin/saved_selections/:id' do
    context 'when the current user owns the selection' do
      it 'deletes the selection and returns 204' do
        sel = make_selection(user: owner)
        delete admin_saved_selection_path(sel)
        expect(response).to have_http_status(:no_content)
        expect(SavedSelection.exists?(sel.id)).to be false
      end
    end

    context 'when the current user does NOT own the selection' do
      it 'returns 403 and does not delete the selection' do
        sel = make_selection(user: other_user)
        delete admin_saved_selection_path(sel)
        expect(response).to have_http_status(:forbidden)
        expect(SavedSelection.exists?(sel.id)).to be true
      end
    end

    context 'when the selection does not exist' do
      it 'returns 404' do
        delete admin_saved_selection_path(0)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /admin/saved_selections (create)
  # ---------------------------------------------------------------------------
  describe 'POST /admin/saved_selections' do
    let(:manifestation) { create(:manifestation) }

    it 'creates a private selection and returns 201' do
      post admin_saved_selections_path,
           params: {
             name: 'My Private',
             shared: false,
             items: [{ type: 'Manifestation', id: manifestation.id }]
           },
           as: :json
      expect(response).to have_http_status(:created)
      sel = SavedSelection.find_by(name: 'My Private')
      expect(sel).to be_present
      expect(sel.shared).to be false
      expect(sel.saved_selection_items.count).to eq(1)
    end

    it 'creates a shared selection' do
      post admin_saved_selections_path,
           params: { name: 'Shared One', shared: true, items: [] },
           as: :json
      expect(response).to have_http_status(:created)
      expect(SavedSelection.find_by(name: 'Shared One').shared).to be true
    end

    it 'returns 422 when name is blank' do
      post admin_saved_selections_path,
           params: { name: '', shared: false, items: [] },
           as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /admin/saved_selections (index)
  # ---------------------------------------------------------------------------
  describe 'GET /admin/saved_selections' do
    it 'returns only selections visible to the current user' do
      own           = make_selection(user: owner, shared: false)
      shared        = make_selection(user: other_user, shared: true)
      private_other = make_selection(user: other_user, shared: false)

      get admin_saved_selections_path
      ids = response.parsed_body.map { |s| s['id'] } # rubocop:disable Rails/Pluck
      expect(ids).to include(own.id, shared.id)
      expect(ids).not_to include(private_other.id)
    end
  end
end
