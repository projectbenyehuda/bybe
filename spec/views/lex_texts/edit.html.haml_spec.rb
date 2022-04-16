require 'rails_helper'

RSpec.describe "lex_texts/edit", type: :view do
  before(:each) do
    @lex_text = assign(:lex_text, LexText.create!(
      title: "MyString",
      authors: "MyString",
      pages: "MyString",
      lex_publication: nil,
      lex_issue: nil,
      manifestation: nil
    ))
  end

  it "renders the edit lex_text form" do
    render

    assert_select "form[action=?][method=?]", lex_text_path(@lex_text), "post" do

      assert_select "input[name=?]", "lex_text[title]"

      assert_select "input[name=?]", "lex_text[authors]"

      assert_select "input[name=?]", "lex_text[pages]"

      assert_select "input[name=?]", "lex_text[lex_publication_id]"

      assert_select "input[name=?]", "lex_text[lex_issue_id]"

      assert_select "input[name=?]", "lex_text[manifestation_id]"
    end
  end
end
