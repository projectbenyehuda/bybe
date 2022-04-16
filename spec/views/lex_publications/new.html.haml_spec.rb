require 'rails_helper'

RSpec.describe "lex_publications/new", type: :view do
  before(:each) do
    assign(:lex_publication, LexPublication.new(
      description: "MyText",
      toc: "MyText",
      az_navbar: false
    ))
  end

  it "renders new lex_publication form" do
    render

    assert_select "form[action=?][method=?]", lex_publications_path, "post" do

      assert_select "textarea[name=?]", "lex_publication[description]"

      assert_select "textarea[name=?]", "lex_publication[toc]"

      assert_select "input[name=?]", "lex_publication[az_navbar]"
    end
  end
end
