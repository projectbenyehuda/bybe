require "rails_helper"

RSpec.describe LexLinksController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/lex_links").to route_to("lex_links#index")
    end

    it "routes to #new" do
      expect(get: "/lex_links/new").to route_to("lex_links#new")
    end

    it "routes to #show" do
      expect(get: "/lex_links/1").to route_to("lex_links#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/lex_links/1/edit").to route_to("lex_links#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/lex_links").to route_to("lex_links#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/lex_links/1").to route_to("lex_links#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/lex_links/1").to route_to("lex_links#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/lex_links/1").to route_to("lex_links#destroy", id: "1")
    end
  end
end
