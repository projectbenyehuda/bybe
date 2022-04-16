require 'rails_helper'

RSpec.describe "lex_files/edit", type: :view do
  before(:each) do
    @lex_file = assign(:lex_file, LexFile.create!(
      fname: "MyString",
      status: 1,
      title: "MyString",
      entrytype: 1,
      comments: "MyText"
    ))
  end

  it "renders the edit lex_file form" do
    render

    assert_select "form[action=?][method=?]", lex_file_path(@lex_file), "post" do

      assert_select "input[name=?]", "lex_file[fname]"

      assert_select "input[name=?]", "lex_file[status]"

      assert_select "input[name=?]", "lex_file[title]"

      assert_select "input[name=?]", "lex_file[entrytype]"

      assert_select "textarea[name=?]", "lex_file[comments]"
    end
  end
end
