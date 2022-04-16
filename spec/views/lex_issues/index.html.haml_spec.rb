require 'rails_helper'

RSpec.describe "lex_issues/index", type: :view do
  before(:each) do
    assign(:lex_issues, [
      LexIssue.create!(
        subtitle: "Subtitle",
        volume: "Volume",
        issue: "Issue",
        seq_num: 2,
        toc: "MyText",
        lex_publication: nil
      ),
      LexIssue.create!(
        subtitle: "Subtitle",
        volume: "Volume",
        issue: "Issue",
        seq_num: 2,
        toc: "MyText",
        lex_publication: nil
      )
    ])
  end

  it "renders a list of lex_issues" do
    render
    assert_select "tr>td", text: "Subtitle".to_s, count: 2
    assert_select "tr>td", text: "Volume".to_s, count: 2
    assert_select "tr>td", text: "Issue".to_s, count: 2
    assert_select "tr>td", text: 2.to_s, count: 2
    assert_select "tr>td", text: "MyText".to_s, count: 2
    assert_select "tr>td", text: nil.to_s, count: 2
  end
end
