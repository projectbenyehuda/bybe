# frozen_string_literal: true

require 'rails_helper'

describe LexCitationGroup do
  let(:person) { create(:lex_entry, :person).lex_item }

  describe 'validations' do
    it 'requires a title' do
      group = build(:lex_citation_group, person: person, title: '  ')
      expect(group).not_to be_valid
      expect(group.errors[:title]).to be_present
    end

    it 'rejects a second heading of the same name for the same person' do
      create(:lex_citation_group, person: person, title: 'ספרים')
      expect(build(:lex_citation_group, person: person, title: 'ספרים')).not_to be_valid
    end

    it 'allows the same name for a different person' do
      create(:lex_citation_group, person: person, title: 'ספרים')
      other = create(:lex_entry, :person).lex_item
      expect(build(:lex_citation_group, person: other, title: 'ספרים')).to be_valid
    end
  end

  describe 'seqno' do
    it 'appends each new heading after the person\'s existing ones' do
      first = create(:lex_citation_group, person: person, title: 'ספרים')
      second = create(:lex_citation_group, person: person, title: 'מאמרים')
      expect([first.seqno, second.seqno]).to eq([1, 2])
    end

    it 'honours an explicitly given seqno' do
      expect(create(:lex_citation_group, person: person, seqno: 7).seqno).to eq(7)
    end

    it 'orders the person\'s headings by seqno' do
      second = create(:lex_citation_group, person: person, title: 'מאמרים', seqno: 2)
      first = create(:lex_citation_group, person: person, title: 'ספרים', seqno: 1)
      expect(person.reload.citation_groups.to_a).to eq([first, second])
    end
  end

  # Removing a heading means "these citations are just general", never "throw these away".
  describe 'destroying a heading' do
    it 'returns its citations to the ungrouped general list' do
      group = create(:lex_citation_group, person: person)
      citation = create(:lex_citation, person: person, citation_group: group)

      expect { group.destroy! }.not_to change(LexCitation, :count)
      expect(citation.reload.citation_group).to be_nil
    end
  end
end
