# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PublicationsController, type: :controller do
  include_context 'when editor logged in', :edit_catalog

  let!(:authority) { create(:authority, name: 'Test Author') }
  let!(:publication) { create(:publication, title: 'Test Publication', authority: authority, status: :todo) }
  let!(:other_publication) { create(:publication, title: 'Other Title', status: :scanned) }

  describe 'GET #index' do
    it 'returns all publications when no filters are applied' do
      get :index
      expect(assigns(:publications)).to include(publication, other_publication)
    end

    it 'filters by title' do
      get :index, params: { title: 'Test' }
      expect(assigns(:publications)).to include(publication)
      expect(assigns(:publications)).not_to include(other_publication)
    end

    it 'filters by author name' do
      get :index, params: { author: 'Test Author' }
      expect(assigns(:publications)).to include(publication)
      expect(assigns(:publications)).not_to include(other_publication)
    end

    it 'filters by status' do
      get :index, params: { status: 'todo' }
      expect(assigns(:publications)).to include(publication)
      expect(assigns(:publications)).not_to include(other_publication)
    end

    it 'handles multiple filters' do
      get :index, params: { title: 'Test', status: 'todo' }
      expect(assigns(:publications)).to include(publication)
      expect(assigns(:publications)).not_to include(other_publication)
    end

    it 'is safe from SQL injection' do
      # This would have broken or returned everything/nothing in a vulnerable version
      get :index, params: { title: "') OR 1=1 --" }
      expect(assigns(:publications)).to be_empty
    end
  end
end
