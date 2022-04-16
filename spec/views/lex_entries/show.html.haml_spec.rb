require 'rails_helper'

RSpec.describe "lex_entries/show", type: :view do
  before(:each) do
    @lex_entry = assign(:lex_entry, LexEntry.create!(
      title: "Title",
      status: "",
      lex_person: nil,
      lex_publication: nil
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Title/)
    expect(rendered).to match(//)
    expect(rendered).to match(//)
    expect(rendered).to match(//)
  end
end
