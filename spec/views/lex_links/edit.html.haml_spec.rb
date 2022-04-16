require 'rails_helper'

RSpec.describe "lex_links/edit", type: :view do
  before(:each) do
    @lex_link = assign(:lex_link, LexLink.create!(
      url: "MyString",
      description: "MyString",
      status: "",
      item: nil
    ))
  end

  it "renders the edit lex_link form" do
    render

    assert_select "form[action=?][method=?]", lex_link_path(@lex_link), "post" do

      assert_select "input[name=?]", "lex_link[url]"

      assert_select "input[name=?]", "lex_link[description]"

      assert_select "input[name=?]", "lex_link[status]"

      assert_select "input[name=?]", "lex_link[item_id]"
    end
  end
end
