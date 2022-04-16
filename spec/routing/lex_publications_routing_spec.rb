require "rails_helper"

RSpec.describe LexPublicationsController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/lex_publications").to route_to("lex_publications#index")
    end

    it "routes to #new" do
      expect(get: "/lex_publications/new").to route_to("lex_publications#new")
    end

    it "routes to #show" do
      expect(get: "/lex_publications/1").to route_to("lex_publications#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/lex_publications/1/edit").to route_to("lex_publications#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/lex_publications").to route_to("lex_publications#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/lex_publications/1").to route_to("lex_publications#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/lex_publications/1").to route_to("lex_publications#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/lex_publications/1").to route_to("lex_publications#destroy", id: "1")
    end
  end
end
