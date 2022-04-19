require 'rails_helper'

RSpec.describe "LexMigrations", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/lex_migration/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /list_files" do
    it "returns http success" do
      get "/lex_migration/list_files"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /analyze_person" do
    it "returns http success" do
      get "/lex_migration/analyze_person"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /analyze_text" do
    it "returns http success" do
      get "/lex_migration/analyze_text"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /analyze_bib" do
    it "returns http success" do
      get "/lex_migration/analyze_bib"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /resolve_entry" do
    it "returns http success" do
      get "/lex_migration/resolve_entry"
      expect(response).to have_http_status(:success)
    end
  end

end
