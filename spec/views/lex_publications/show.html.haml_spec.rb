require 'rails_helper'

RSpec.describe "lex_publications/show", type: :view do
  before(:each) do
    @lex_publication = assign(:lex_publication, LexPublication.create!(
      description: "MyText",
      toc: "MyText",
      az_navbar: false
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/false/)
  end
end
