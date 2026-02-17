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

  describe '.citations_by_subject_title' do
    subject(:result) { person.citations_by_subject_title(subject_title) }

    let(:person) { create(:lex_person) }
    let(:work_1) { create(:lex_person_work, person: person, title: 'Work A') }
    let(:work_2) { create(:lex_person_work, person: person, title: 'Work B') }
    let!(:citation_1) { create(:lex_citation, person: person, person_work: work_1) }
    let!(:citation_2) { create(:lex_citation, person: person, person_work: work_2) }
    let!(:citation_3) { create(:lex_citation, person: person, subject: 'Work B', person_work: nil) }
    let!(:citation_general) { create(:lex_citation, person: person, subject: nil, person_work: nil) }

    context 'when subject_title matches person_work title' do
      let(:subject_title) { 'Work A' }

      it 'returns citations with the given title from person_work' do
        expect(result).to eq([citation_1])
      end
    end

    context 'when subject_title matches both person_work title and subject field' do
      let(:subject_title) { 'Work B' }

      it 'returns citations with the given subject_title from person_work and subject field' do
        expect(result).to match_array([citation_2, citation_3])
      end
    end

    context 'when subject_title is a nil' do
      let(:subject_title) { nil }

      it 'returns general citations not tied to specific work' do
        expect(result).to eq([citation_general])
      end
    end

    context 'when subject_title is not found in any citation' do
      let(:subject_title) { 'Bambarbia Kirgudu' }

      it 'returns empty array' do
        expect(result).to eq([])
      end
    end
  end

  describe '.max_citation_seqno_by_subject_title' do
    subject(:result) do
      person.max_citation_seqno_by_subject_title(subject_title, exclude_citation_id: exclude_citation_id)
    end

    let(:person) { create(:lex_person) }
    let(:exclude_citation_id) { nil }

    let!(:citation_A1) { create(:lex_citation, person: person, subject: 'Work A', seqno: 1) }
    let!(:citation_A2) { create(:lex_citation, person: person, subject: 'Work A', seqno: 2) }
    let!(:citation_A3) { create(:lex_citation, person: person, subject: 'Work A', seqno: 4) }

    context 'when there are citations with the given subject_title' do
      let(:subject_title) { 'Work A' }

      it 'returns the maximum seqno among those citations' do
        expect(result).to eq(4)
      end

      context 'when exclude_citation_id is provided' do
        let(:exclude_citation_id) { citation_A3.id }

        it 'excludes the specified citation from the calculation' do
          expect(result).to eq(2)
        end
      end

      context 'when non-existent exclude_citation_id is provided' do
        let(:exclude_citation_id) { -1 }

        it 'ignores the non-existent ID and returns max seqno as usual' do
          expect(result).to eq(4)
        end
      end
    end

    context 'when given subject_title has no citations' do
      let(:subject_title) { 'Work X' }

      it 'returns 0' do
        expect(result).to eq(0)
      end
    end

    context 'when nil subject_title is passed' do
      let(:subject_title) { nil }

      context 'when there are general citations' do
        let!(:general_citation_1) { create(:lex_citation, person: person, seqno: 1) }

        it 'returns max seqno among general citations' do
          expect(result).to eq(1)
        end
      end

      context 'when no general citations exist' do
        it 'returns 0' do
          expect(result).to eq(0)
        end
      end
    end
  end
end
