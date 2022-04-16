require 'rails_helper'

RSpec.describe "lex_citations/new", type: :view do
  before(:each) do
    assign(:lex_citation, LexCitation.new(
      title: "MyString",
      from_publication: "MyString",
      authors: "MyString",
      pages: "MyString",
      link: "MyString",
      item: nil,
      manifestation: nil
    ))
  end

  it "renders new lex_citation form" do
    render

    assert_select "form[action=?][method=?]", lex_citations_path, "post" do

      assert_select "input[name=?]", "lex_citation[title]"

      assert_select "input[name=?]", "lex_citation[from_publication]"

      assert_select "input[name=?]", "lex_citation[authors]"

      assert_select "input[name=?]", "lex_citation[pages]"

      assert_select "input[name=?]", "lex_citation[link]"

      assert_select "input[name=?]", "lex_citation[item_id]"

      assert_select "input[name=?]", "lex_citation[manifestation_id]"
    end
  end
end
