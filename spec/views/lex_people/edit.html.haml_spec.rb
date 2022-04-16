require 'rails_helper'

RSpec.describe "lex_people/edit", type: :view do
  before(:each) do
    @lex_person = assign(:lex_person, LexPerson.create!(
      aliases: "MyString",
      copyrighted: false,
      birthdate: "MyString",
      deathdate: "MyString",
      bio: "MyText",
      works: "MyText",
      about: "MyText"
    ))
  end

  it "renders the edit lex_person form" do
    render

    assert_select "form[action=?][method=?]", lex_person_path(@lex_person), "post" do

      assert_select "input[name=?]", "lex_person[aliases]"

      assert_select "input[name=?]", "lex_person[copyrighted]"

      assert_select "input[name=?]", "lex_person[birthdate]"

      assert_select "input[name=?]", "lex_person[deathdate]"

      assert_select "textarea[name=?]", "lex_person[bio]"

      assert_select "textarea[name=?]", "lex_person[works]"

      assert_select "textarea[name=?]", "lex_person[about]"
    end
  end
end
