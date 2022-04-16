require 'rails_helper'

RSpec.describe "lex_links/show", type: :view do
  before(:each) do
    @lex_link = assign(:lex_link, LexLink.create!(
      url: "Url",
      description: "Description",
      status: "",
      item: nil
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Url/)
    expect(rendered).to match(/Description/)
    expect(rendered).to match(//)
    expect(rendered).to match(//)
  end
end
