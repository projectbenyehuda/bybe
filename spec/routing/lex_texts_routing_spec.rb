require "rails_helper"

RSpec.describe LexTextsController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/lex_texts").to route_to("lex_texts#index")
    end

    it "routes to #new" do
      expect(get: "/lex_texts/new").to route_to("lex_texts#new")
    end

    it "routes to #show" do
      expect(get: "/lex_texts/1").to route_to("lex_texts#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/lex_texts/1/edit").to route_to("lex_texts#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/lex_texts").to route_to("lex_texts#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/lex_texts/1").to route_to("lex_texts#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/lex_texts/1").to route_to("lex_texts#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/lex_texts/1").to route_to("lex_texts#destroy", id: "1")
    end
  end
end
