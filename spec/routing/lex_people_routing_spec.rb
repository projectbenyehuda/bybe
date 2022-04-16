require "rails_helper"

RSpec.describe LexPeopleController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/lex_people").to route_to("lex_people#index")
    end

    it "routes to #new" do
      expect(get: "/lex_people/new").to route_to("lex_people#new")
    end

    it "routes to #show" do
      expect(get: "/lex_people/1").to route_to("lex_people#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/lex_people/1/edit").to route_to("lex_people#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/lex_people").to route_to("lex_people#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/lex_people/1").to route_to("lex_people#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/lex_people/1").to route_to("lex_people#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/lex_people/1").to route_to("lex_people#destroy", id: "1")
    end
  end
end
