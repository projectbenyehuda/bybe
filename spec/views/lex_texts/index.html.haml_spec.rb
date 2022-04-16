require 'rails_helper'

RSpec.describe "lex_texts/index", type: :view do
  before(:each) do
    assign(:lex_texts, [
      LexText.create!(
        title: "Title",
        authors: "Authors",
        pages: "Pages",
        lex_publication: nil,
        lex_issue: nil,
        manifestation: nil
      ),
      LexText.create!(
        title: "Title",
        authors: "Authors",
        pages: "Pages",
        lex_publication: nil,
        lex_issue: nil,
        manifestation: nil
      )
    ])
  end

  it "renders a list of lex_texts" do
    render
    assert_select "tr>td", text: "Title".to_s, count: 2
    assert_select "tr>td", text: "Authors".to_s, count: 2
    assert_select "tr>td", text: "Pages".to_s, count: 2
    assert_select "tr>td", text: nil.to_s, count: 2
    assert_select "tr>td", text: nil.to_s, count: 2
    assert_select "tr>td", text: nil.to_s, count: 2
  end
end
