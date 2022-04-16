require 'rails_helper'

RSpec.describe "lex_issues/edit", type: :view do
  before(:each) do
    @lex_issue = assign(:lex_issue, LexIssue.create!(
      subtitle: "MyString",
      volume: "MyString",
      issue: "MyString",
      seq_num: 1,
      toc: "MyText",
      lex_publication: nil
    ))
  end

  it "renders the edit lex_issue form" do
    render

    assert_select "form[action=?][method=?]", lex_issue_path(@lex_issue), "post" do

      assert_select "input[name=?]", "lex_issue[subtitle]"

      assert_select "input[name=?]", "lex_issue[volume]"

      assert_select "input[name=?]", "lex_issue[issue]"

      assert_select "input[name=?]", "lex_issue[seq_num]"

      assert_select "textarea[name=?]", "lex_issue[toc]"

      assert_select "input[name=?]", "lex_issue[lex_publication_id]"
    end
  end
end
