require 'rails_helper'

RSpec.describe "lex_entries/new", type: :view do
  before(:each) do
    assign(:lex_entry, LexEntry.new(
      title: "MyString",
      status: "",
      lex_person: nil,
      lex_publication: nil
    ))
  end

  it "renders new lex_entry form" do
    render

    assert_select "form[action=?][method=?]", lex_entries_path, "post" do

      assert_select "input[name=?]", "lex_entry[title]"

      assert_select "input[name=?]", "lex_entry[status]"

      assert_select "input[name=?]", "lex_entry[lex_person_id]"

      assert_select "input[name=?]", "lex_entry[lex_publication_id]"
    end
  end
end
