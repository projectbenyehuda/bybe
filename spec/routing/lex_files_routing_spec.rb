require "rails_helper"

RSpec.describe LexFilesController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/lex_files").to route_to("lex_files#index")
    end

    it "routes to #new" do
      expect(get: "/lex_files/new").to route_to("lex_files#new")
    end

    it "routes to #show" do
      expect(get: "/lex_files/1").to route_to("lex_files#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/lex_files/1/edit").to route_to("lex_files#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/lex_files").to route_to("lex_files#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/lex_files/1").to route_to("lex_files#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/lex_files/1").to route_to("lex_files#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/lex_files/1").to route_to("lex_files#destroy", id: "1")
    end
  end
end
