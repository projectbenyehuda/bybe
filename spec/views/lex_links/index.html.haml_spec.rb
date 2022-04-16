require 'rails_helper'

RSpec.describe "lex_links/index", type: :view do
  before(:each) do
    assign(:lex_links, [
      LexLink.create!(
        url: "Url",
        description: "Description",
        status: "",
        item: nil
      ),
      LexLink.create!(
        url: "Url",
        description: "Description",
        status: "",
        item: nil
      )
    ])
  end

  it "renders a list of lex_links" do
    render
    assert_select "tr>td", text: "Url".to_s, count: 2
    assert_select "tr>td", text: "Description".to_s, count: 2
    assert_select "tr>td", text: "".to_s, count: 2
    assert_select "tr>td", text: nil.to_s, count: 2
  end
end
