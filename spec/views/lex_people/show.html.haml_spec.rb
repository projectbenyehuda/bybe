require 'rails_helper'

RSpec.describe "lex_people/show", type: :view do
  before(:each) do
    @lex_person = assign(:lex_person, LexPerson.create!(
      aliases: "Aliases",
      copyrighted: false,
      birthdate: "Birthdate",
      deathdate: "Deathdate",
      bio: "MyText",
      works: "MyText",
      about: "MyText"
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Aliases/)
    expect(rendered).to match(/false/)
    expect(rendered).to match(/Birthdate/)
    expect(rendered).to match(/Deathdate/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/MyText/)
  end
end
