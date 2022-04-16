require "rails_helper"

RSpec.describe LexIssuesController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/lex_issues").to route_to("lex_issues#index")
    end

    it "routes to #new" do
      expect(get: "/lex_issues/new").to route_to("lex_issues#new")
    end

    it "routes to #show" do
      expect(get: "/lex_issues/1").to route_to("lex_issues#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/lex_issues/1/edit").to route_to("lex_issues#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/lex_issues").to route_to("lex_issues#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/lex_issues/1").to route_to("lex_issues#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/lex_issues/1").to route_to("lex_issues#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/lex_issues/1").to route_to("lex_issues#destroy", id: "1")
    end
  end
end
