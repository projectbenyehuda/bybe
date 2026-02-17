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
    let(:person) { create(:lex_person) }
    let(:work1) { create(:lex_person_work, person: person, title: 'Work A') }
    let(:work2) { create(:lex_person_work, person: person, title: 'Work B') }
    let!(:citations_work1) { create_list(:lex_citation, 2, person: person, person_work: work1) }
    let!(:citation_work2) { create(:lex_citation, person: person, person_work: work2) }
    let!(:citation_subject) { create(:lex_citation, person: person, subject: 'Subject C', lex_person_work_id: nil) }

    it 'returns citations with the given subject_title from person_work' do
      expect(person.citations_by_subject_title('Work A')).to match_array(citations_work1)
      expect(person.citations_by_subject_title('Work B')).to eq([citation_work2])
    end

    it 'returns citations with the given subject_title from subject field' do
      expect(person.citations_by_subject_title('Subject C')).to eq([citation_subject])
    end

    it 'returns empty array if no citations with given subject_title found' do
      expect(person.citations_by_subject_title('Nonexistent')).to eq([])
    end

    it 'handles nil subject_title' do
      citation_nil = create(:lex_citation, person: person, subject: nil, lex_person_work_id: nil)
      expect(person.citations_by_subject_title(nil)).to eq([citation_nil])
    end
  end

  describe '.max_citation_seqno_by_subject_title' do
    let(:person) { create(:lex_person) }
    let(:work1) { create(:lex_person_work, person: person, title: 'Work A') }
    let(:work2) { create(:lex_person_work, person: person, title: 'Work B') }

    let!(:citations_work1) do
      [
        create(:lex_citation, person: person, person_work: work1, seqno: 3),
        create(:lex_citation, person: person, person_work: work1, seqno: 1)
      ]
    end
    let!(:citation_work2) { create(:lex_citation, person: person, person_work: work2, seqno: 5) }

    it 'returns max citation seqno for given subject_title' do
      expect(person.max_citation_seqno_by_subject_title('Work A')).to eq(3)
      expect(person.max_citation_seqno_by_subject_title('Work B')).to eq(5)
    end

    it 'returns 0 if no citations with given subject_title exist' do
      expect(person.max_citation_seqno_by_subject_title('Nonexistent')).to eq(0)
    end

    context 'with exclude_citation_id parameter' do
      let!(:citation_to_exclude) { create(:lex_citation, person: person, person_work: work1, seqno: 10) }

      it 'excludes the specified citation from max calculation' do
        expect(person.max_citation_seqno_by_subject_title('Work A', exclude_citation_id: citation_to_exclude.id))
          .to eq(3)
      end

      it 'includes all citations if exclude_citation_id is nil' do
        expect(person.max_citation_seqno_by_subject_title('Work A', exclude_citation_id: nil)).to eq(10)
      end

      it 'returns 0 when only excluded citation exists for subject_title' do
        work3 = create(:lex_person_work, person: person, title: 'Work C')
        only_citation = create(:lex_citation, person: person, person_work: work3, seqno: 7)
        expect(person.max_citation_seqno_by_subject_title('Work C', exclude_citation_id: only_citation.id))
          .to eq(0)
      end
    end
  end
end
