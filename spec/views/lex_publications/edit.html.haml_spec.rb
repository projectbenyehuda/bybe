require 'rails_helper'

RSpec.describe "lex_publications/edit", type: :view do
  before(:each) do
    @lex_publication = assign(:lex_publication, LexPublication.create!(
      description: "MyText",
      toc: "MyText",
      az_navbar: false
    ))
  end

  it "renders the edit lex_publication form" do
    render

    assert_select "form[action=?][method=?]", lex_publication_path(@lex_publication), "post" do

      assert_select "textarea[name=?]", "lex_publication[description]"

      assert_select "textarea[name=?]", "lex_publication[toc]"

      assert_select "input[name=?]", "lex_publication[az_navbar]"
    end
  end
end
