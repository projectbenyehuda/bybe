require 'rails_helper'

RSpec.describe "lex_files/index", type: :view do
  before(:each) do
    assign(:lex_files, [
      LexFile.create!(
        fname: "Fname",
        status: 2,
        title: "Title",
        entrytype: 3,
        comments: "MyText"
      ),
      LexFile.create!(
        fname: "Fname",
        status: 2,
        title: "Title",
        entrytype: 3,
        comments: "MyText"
      )
    ])
  end

  it "renders a list of lex_files" do
    render
    assert_select "tr>td", text: "Fname".to_s, count: 2
    assert_select "tr>td", text: 2.to_s, count: 2
    assert_select "tr>td", text: "Title".to_s, count: 2
    assert_select "tr>td", text: 3.to_s, count: 2
    assert_select "tr>td", text: "MyText".to_s, count: 2
  end
end
