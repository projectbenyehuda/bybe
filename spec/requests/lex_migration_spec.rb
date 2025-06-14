require 'rails_helper'

RSpec.describe 'LexMigrations', type: :request do
  describe 'GET /index' do
    it 'returns http success' do
      get '/lex_migration/index'
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /list_files' do
    it 'returns http success' do
      get '/lex_migration/list_files'
      expect(response).to have_http_status(:success)
    end
  end
end
