# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::LexPersonContent do
  subject(:result) { described_class.call(lex_person) }

  let(:lex_person) do
    create(:lex_entry, :person).lex_item.tap do |lex_person|
      lex_person.deathdate = '1923'
      lex_person.birthdate = '1987'
      lex_person.citations = build_list(:lex_citation, 3)
      lex_person.works = build_list(:lex_person_work, 2)
      lex_person.save!
    end
  end

  it 'completes successfully' do
    puts result
    expect(result).to be_present
  end
end
