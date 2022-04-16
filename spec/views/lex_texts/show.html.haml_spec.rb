require 'rails_helper'

RSpec.describe "lex_texts/show", type: :view do
  before(:each) do
    @lex_text = assign(:lex_text, LexText.create!(
      title: "Title",
      authors: "Authors",
      pages: "Pages",
      lex_publication: nil,
      lex_issue: nil,
      manifestation: nil
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Title/)
    expect(rendered).to match(/Authors/)
    expect(rendered).to match(/Pages/)
    expect(rendered).to match(//)
    expect(rendered).to match(//)
    expect(rendered).to match(//)
  end
end
