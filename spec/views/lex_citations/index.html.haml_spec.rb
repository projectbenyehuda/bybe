require 'rails_helper'

RSpec.describe "lex_citations/index", type: :view do
  before(:each) do
    assign(:lex_citations, [
      LexCitation.create!(
        title: "Title",
        from_publication: "From Publication",
        authors: "Authors",
        pages: "Pages",
        link: "Link",
        item: nil,
        manifestation: nil
      ),
      LexCitation.create!(
        title: "Title",
        from_publication: "From Publication",
        authors: "Authors",
        pages: "Pages",
        link: "Link",
        item: nil,
        manifestation: nil
      )
    ])
  end

  it "renders a list of lex_citations" do
    render
    assert_select "tr>td", text: "Title".to_s, count: 2
    assert_select "tr>td", text: "From Publication".to_s, count: 2
    assert_select "tr>td", text: "Authors".to_s, count: 2
    assert_select "tr>td", text: "Pages".to_s, count: 2
    assert_select "tr>td", text: "Link".to_s, count: 2
    assert_select "tr>td", text: nil.to_s, count: 2
    assert_select "tr>td", text: nil.to_s, count: 2
  end
end
