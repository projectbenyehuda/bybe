require 'rails_helper'

RSpec.describe "lex_citations/show", type: :view do
  before(:each) do
    @lex_citation = assign(:lex_citation, LexCitation.create!(
      title: "Title",
      from_publication: "From Publication",
      authors: "Authors",
      pages: "Pages",
      link: "Link",
      item: nil,
      manifestation: nil
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Title/)
    expect(rendered).to match(/From Publication/)
    expect(rendered).to match(/Authors/)
    expect(rendered).to match(/Pages/)
    expect(rendered).to match(/Link/)
    expect(rendered).to match(//)
    expect(rendered).to match(//)
  end
end
