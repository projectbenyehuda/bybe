require 'rails_helper'

RSpec.describe "lex_entries/index", type: :view do
  before(:each) do
    assign(:lex_entries, [
      LexEntry.create!(
        title: "Title",
        status: "",
        lex_person: nil,
        lex_publication: nil
      ),
      LexEntry.create!(
        title: "Title",
        status: "",
        lex_person: nil,
        lex_publication: nil
      )
    ])
  end

  it "renders a list of lex_entries" do
    render
    assert_select "tr>td", text: "Title".to_s, count: 2
    assert_select "tr>td", text: "".to_s, count: 2
    assert_select "tr>td", text: nil.to_s, count: 2
    assert_select "tr>td", text: nil.to_s, count: 2
  end
end
