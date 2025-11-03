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

    it 'deletes a manifestation' do
      expect do
        delete :destroy_manifestation, params: { id: manifestations.first.id }
      end.to change { Manifestation.count }.by(-1)
    end

    it 'deletes a manifestation via JSON' do
      expect do
        delete :destroy_manifestation, params: { id: manifestations.first.id }, format: :json
      end.to change { Manifestation.count }.by(-1)
      
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['id']).to eq(manifestations.first.id.to_s)
    end

    it 'unpublishes a manifestation' do
      post :unpublish_manifestation, params: { id: manifestations.last.id }
      expect(manifestations.last.reload.status).to eq('unpublished')
    end

    it 'unpublishes a manifestation via JSON' do
      post :unpublish_manifestation, params: { id: manifestations.last.id }, format: :json
      expect(manifestations.last.reload.status).to eq('unpublished')
      
      json_response = JSON.parse(response.body)
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
