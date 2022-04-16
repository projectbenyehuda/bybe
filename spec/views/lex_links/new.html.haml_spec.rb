require 'rails_helper'

RSpec.describe "lex_links/new", type: :view do
  before(:each) do
    assign(:lex_link, LexLink.new(
      url: "MyString",
      description: "MyString",
      status: "",
      item: nil
    ))
  end

  it "renders new lex_link form" do
    render

    assert_select "form[action=?][method=?]", lex_links_path, "post" do

      assert_select "input[name=?]", "lex_link[url]"

      assert_select "input[name=?]", "lex_link[description]"

      assert_select "input[name=?]", "lex_link[status]"

      assert_select "input[name=?]", "lex_link[item_id]"
    end
  end
end
