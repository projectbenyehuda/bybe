require 'rails_helper'

RSpec.describe "lex_issues/show", type: :view do
  before(:each) do
    @lex_issue = assign(:lex_issue, LexIssue.create!(
      subtitle: "Subtitle",
      volume: "Volume",
      issue: "Issue",
      seq_num: 2,
      toc: "MyText",
      lex_publication: nil
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Subtitle/)
    expect(rendered).to match(/Volume/)
    expect(rendered).to match(/Issue/)
    expect(rendered).to match(/2/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(//)
  end
end
