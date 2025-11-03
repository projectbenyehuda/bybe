require 'rails_helper'

# describe 'Admin Manifestation Batch Tools', type: :request do
describe AdminController do
  describe 'Admin Manifestation Batch Tools' do
    include_context 'Admin user logged in'
    let!(:manifestations) do
      [
        create(:manifestation, title: 'Test 1', status: :published),
        create(:manifestation, title: 'Test 2', status: :published)
      ]
    end

    it 'renders the batch tool page for admins' do
      get :manifestation_batch_tools

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('admin.manifestation_batch_tools.title'))
    end

    it 'lists manifestations by whitespace-delimited IDs' do
      get :manifestation_batch_tools, params: { ids: manifestations.map(&:id).join(' ') }
      expect(response.body).to include('Test 1')
      expect(response.body).to include('Test 2')
    end

    it 'supports range notation with minus character' do
      # Create manifestations with sequential IDs
      m1 = create(:manifestation, title: 'Range Test 1', status: :published)
      m2 = create(:manifestation, title: 'Range Test 2', status: :published)
      m3 = create(:manifestation, title: 'Range Test 3', status: :published)

      # Use range notation
      get :manifestation_batch_tools, params: { ids: "#{m1.id}-#{m3.id}" }

      expect(response.body).to include('Range Test 1')
      expect(response.body).to include('Range Test 2')
      expect(response.body).to include('Range Test 3')
    end

    it 'supports range notation with en-dash character' do
      # Create manifestations with sequential IDs
      m1 = create(:manifestation, title: 'Dash Test 1', status: :published)
      m2 = create(:manifestation, title: 'Dash Test 2', status: :published)
      m3 = create(:manifestation, title: 'Dash Test 3', status: :published)

      # Use en-dash range notation
      get :manifestation_batch_tools, params: { ids: "#{m1.id}–#{m3.id}" }

      expect(response.body).to include('Dash Test 1')
      expect(response.body).to include('Dash Test 2')
      expect(response.body).to include('Dash Test 3')
    end

    it 'supports mixed ranges and individual IDs' do
      # Create manifestations
      m1 = create(:manifestation, title: 'Mixed 1', status: :published)
      m2 = create(:manifestation, title: 'Mixed 2', status: :published)
      m3 = create(:manifestation, title: 'Mixed 3', status: :published)
      m4 = create(:manifestation, title: 'Mixed 4', status: :published)

      # Mix ranges and individual IDs
      get :manifestation_batch_tools, params: { ids: "#{m1.id}-#{m2.id} #{m4.id}" }

      expect(response.body).to include('Mixed 1')
      expect(response.body).to include('Mixed 2')
      expect(response.body).not_to include('Mixed 3')
      expect(response.body).to include('Mixed 4')
    end

    it 'deletes a manifestation' do
      expect do
        delete :destroy_manifestation, params: { id: manifestations.first.id }
      end.to change { Manifestation.count }.by(-1)
    end

    it 'deletes a manifestation via JSON' do
      deleted_id = manifestations.first.id
      expect do
        delete :destroy_manifestation, params: { id: deleted_id }, format: :json
      end.to change(Manifestation, :count).by(-1)

      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['id']).to eq(deleted_id.to_s)
    end

    it 'unpublishes a manifestation' do
      post :unpublish_manifestation, params: { id: manifestations.last.id }
      expect(manifestations.last.reload.status).to eq('unpublished')
    end

    it 'unpublishes a manifestation via JSON' do
      post :unpublish_manifestation, params: { id: manifestations.last.id }, format: :json
      expect(manifestations.last.reload.status).to eq('unpublished')

      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['id']).to eq(manifestations.last.id.to_s)
    end
  end

  describe 'Non-admins denied access' do
    it 'denies access to non-admins' do
      user = create(:user, :admin)
      # post test_session_path, params: { variables: { user_id: user.id } }
      session[:user_id] = user.id
      get :manifestation_batch_tools
      expect(response).to have_http_status(:redirect)
    end
  end
end
