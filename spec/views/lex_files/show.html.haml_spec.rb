require 'rails_helper'

RSpec.describe "lex_files/show", type: :view do
  before(:each) do
    @lex_file = assign(:lex_file, LexFile.create!(
      fname: "Fname",
      status: 2,
      title: "Title",
      entrytype: 3,
      comments: "MyText"
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Fname/)
    expect(rendered).to match(/2/)
    expect(rendered).to match(/Title/)
    expect(rendered).to match(/3/)
    expect(rendered).to match(/MyText/)
  end
end
