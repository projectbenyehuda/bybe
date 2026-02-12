# frozen_string_literal: true

require 'rails_helper'

describe LexPerson do
  describe '.works_by_type' do
    let(:person) { create(:lex_person) }
    let!(:original_works) { create_list(:lex_person_work, 2, person: person, work_type: :original) }
    let!(:translated_work) { create(:lex_person_work, person: person, work_type: :translated) }

    it 'returns works of the given type' do
      expect(person.works_by_type('original')).to eq(original_works)
    end

    it 'accepts symbol work types' do
      expect(person.works_by_type(:translated)).to eq([translated_work])
    end

    it 'returns empty array if no works of given type found' do
      expect(person.works_by_type('edited')).to eq([])
    end
  end

  describe '.max_work_seqno_by_type' do
    let(:person) { create(:lex_person) }
    let!(:original_works) do
      [
        create(:lex_person_work, person: person, work_type: :original, seqno: 2),
        create(:lex_person_work, person: person, work_type: :original, seqno: 1)
      ]
    end
    let!(:translated_work) { create(:lex_person_work, person: person, work_type: :translated, seqno: 5) }

    it 'returns max work seqno by given type' do
      expect(person.max_work_seqno_by_type('original')).to eq(2)
      expect(person.max_work_seqno_by_type('translated')).to eq(5)
    end

    it 'returns 0 if no works of given type exists' do
      expect(person.max_work_seqno_by_type('edited')).to eq(0)
    end
  end
end
