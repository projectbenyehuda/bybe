require 'rails_helper'

RSpec.describe "lex_entries/edit", type: :view do
  before(:each) do
    @lex_entry = assign(:lex_entry, LexEntry.create!(
      title: "MyString",
      status: "",
      lex_person: nil,
      lex_publication: nil
    ))
  end

  it "renders the edit lex_entry form" do
    render

    assert_select "form[action=?][method=?]", lex_entry_path(@lex_entry), "post" do

      assert_select "input[name=?]", "lex_entry[title]"

      assert_select "input[name=?]", "lex_entry[status]"

      assert_select "input[name=?]", "lex_entry[lex_person_id]"

      assert_select "input[name=?]", "lex_entry[lex_publication_id]"
    end
  end
end
