require "rails_helper"

RSpec.describe LexEntriesController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/lex_entries").to route_to("lex_entries#index")
    end

    it "routes to #new" do
      expect(get: "/lex_entries/new").to route_to("lex_entries#new")
    end

    it "routes to #show" do
      expect(get: "/lex_entries/1").to route_to("lex_entries#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/lex_entries/1/edit").to route_to("lex_entries#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/lex_entries").to route_to("lex_entries#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/lex_entries/1").to route_to("lex_entries#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/lex_entries/1").to route_to("lex_entries#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/lex_entries/1").to route_to("lex_entries#destroy", id: "1")
    end
  end
end
