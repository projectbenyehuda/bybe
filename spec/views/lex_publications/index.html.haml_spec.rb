require 'rails_helper'

RSpec.describe "lex_publications/index", type: :view do
  before(:each) do
    assign(:lex_publications, [
      LexPublication.create!(
        description: "MyText",
        toc: "MyText",
        az_navbar: false
      ),
      LexPublication.create!(
        description: "MyText",
        toc: "MyText",
        az_navbar: false
      )
    ])
  end

  it "renders a list of lex_publications" do
    render
    assert_select "tr>td", text: "MyText".to_s, count: 2
    assert_select "tr>td", text: "MyText".to_s, count: 2
    assert_select "tr>td", text: false.to_s, count: 2
  end
end
