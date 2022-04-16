require "rails_helper"

RSpec.describe LexCitationsController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/lex_citations").to route_to("lex_citations#index")
    end

    it "routes to #new" do
      expect(get: "/lex_citations/new").to route_to("lex_citations#new")
    end

    it "routes to #show" do
      expect(get: "/lex_citations/1").to route_to("lex_citations#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/lex_citations/1/edit").to route_to("lex_citations#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/lex_citations").to route_to("lex_citations#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/lex_citations/1").to route_to("lex_citations#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/lex_citations/1").to route_to("lex_citations#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/lex_citations/1").to route_to("lex_citations#destroy", id: "1")
    end
  end
end
