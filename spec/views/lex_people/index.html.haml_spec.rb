require 'rails_helper'

RSpec.describe "lex_people/index", type: :view do
  before(:each) do
    assign(:lex_people, [
      LexPerson.create!(
        aliases: "Aliases",
        copyrighted: false,
        birthdate: "Birthdate",
        deathdate: "Deathdate",
        bio: "MyText",
        works: "MyText",
        about: "MyText"
      ),
      LexPerson.create!(
        aliases: "Aliases",
        copyrighted: false,
        birthdate: "Birthdate",
        deathdate: "Deathdate",
        bio: "MyText",
        works: "MyText",
        about: "MyText"
      )
    ])
  end

  it "renders a list of lex_people" do
    render
    assert_select "tr>td", text: "Aliases".to_s, count: 2
    assert_select "tr>td", text: false.to_s, count: 2
    assert_select "tr>td", text: "Birthdate".to_s, count: 2
    assert_select "tr>td", text: "Deathdate".to_s, count: 2
    assert_select "tr>td", text: "MyText".to_s, count: 2
    assert_select "tr>td", text: "MyText".to_s, count: 2
    assert_select "tr>td", text: "MyText".to_s, count: 2
  end
end
