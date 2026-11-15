# frozen_string_literal: true

require 'rails_helper'

describe LexPersonWorkGroup do
  let(:person) { create(:lex_entry, :person).lex_item }

  describe 'validations' do
    it 'requires a title' do
      group = build(:lex_person_work_group, person: person, title: '  ')
      expect(group).not_to be_valid
      expect(group.errors[:title]).to be_present
    end

    it 'rejects a second sub-heading of the same name in the same section' do
      create(:lex_person_work_group, person: person, title: 'עיון')
      expect(build(:lex_person_work_group, person: person, title: 'עיון')).not_to be_valid
    end

    it 'allows the same name in another section' do
      create(:lex_person_work_group, person: person, title: 'עיון')
      expect(build(:lex_person_work_group, person: person, title: 'עיון', work_type: 'edited')).to be_valid
    end
  end

  describe 'seqno' do
    it 'numbers sub-headings separately within each section' do
      first = create(:lex_person_work_group, person: person, title: 'שירה')
      edited = create(:lex_person_work_group, person: person, title: 'ספרי עיון', work_type: 'edited')
      second = create(:lex_person_work_group, person: person, title: 'עיון')
      expect([first.seqno, second.seqno, edited.seqno]).to eq([1, 2, 1])
    end

    it 'puts a sub-heading moved to another section last among that section\'s sub-headings' do
      create(:lex_person_work_group, person: person, title: 'ספרי עיון', work_type: 'edited')
      group = create(:lex_person_work_group, person: person, title: 'עריכת תרגום')
      group.update!(work_type: 'edited')
      expect(group.seqno).to eq(2)
    end
  end

  describe 'changing the work type' do
    it 'takes the sub-heading\'s works along to the new section' do
      group = create(:lex_person_work_group, person: person)
      work = create(:lex_person_work, person: person, work_group: group)
      other = create(:lex_person_work, person: person, work_type: 'original')

      group.update!(work_type: 'edited')

      expect(work.reload).to have_attributes(work_type: 'edited', work_group: group)
      expect(other.reload.work_type).to eq('original')
    end
  end

  # Removing a sub-heading means "these are just works", never "throw these away".
  describe 'destroying a sub-heading' do
    it 'returns its works to the ungrouped list of their section' do
      group = create(:lex_person_work_group, person: person, work_type: 'translated')
      work = create(:lex_person_work, person: person, work_group: group)

      expect { group.destroy! }.not_to change(LexPersonWork, :count)
      expect(work.reload).to have_attributes(work_group: nil, work_type: 'translated')
    end
  end
end
