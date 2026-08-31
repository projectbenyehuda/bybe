# frozen_string_literal: true

require 'rails_helper'

describe LexPerson do
  describe '#unmatched_publications' do
    let(:authority) { create(:authority) }
    let(:person) { create(:lex_person, authority: authority) }

    it 'returns an empty relation when the person has no authority' do
      person = create(:lex_person, authority: nil)
      create(:publication)

      expect(person.unmatched_publications).to be_empty
    end

    it "excludes publications linked to one of the person's works" do
      matched = create(:publication, authority: authority)
      unmatched = create(:publication, authority: authority)
      create(:lex_person_work, person: person, publication: matched)
      create(:lex_person_work, person: person, publication: nil)

      expect(person.unmatched_publications).to contain_exactly(unmatched)
    end

    it 'ignores publications of other authorities and works of other people' do
      unmatched = create(:publication, authority: authority)
      other_authority_pub = create(:publication)
      create(:lex_person_work, person: create(:lex_person), publication: unmatched)

      expect(person.unmatched_publications).to contain_exactly(unmatched)
      expect(person.unmatched_publications).not_to include(other_authority_pub)
    end
  end

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

  describe '.citations_by_group_token' do
    subject(:result) { person.citations_by_group_token(group_token) }

    let(:person) { create(:lex_person) }
    let(:work_1) { create(:lex_person_work, person: person, title: 'Work A') }
    let(:work_2) { create(:lex_person_work, person: person, title: 'Work B') }
    let(:group) { create(:lex_citation_group, person: person, title: 'Work B') }
    let!(:citation_1) { create(:lex_citation, person: person, person_work: work_1) }
    let!(:citation_2) { create(:lex_citation, person: person, person_work: work_2) }
    let!(:citation_3) { create(:lex_citation, person: person, subject: 'Work B', person_work: nil) }
    let!(:citation_general) { create(:lex_citation, person: person, subject: nil, person_work: nil) }
    let!(:citation_grouped) { create(:lex_citation, person: person, citation_group: group) }

    context 'when the token is a person_work title' do
      let(:group_token) { 'Work A' }

      it 'returns citations with the given title from person_work' do
        expect(result).to eq([citation_1])
      end
    end

    context 'when the token matches both a person_work title and a legacy subject' do
      let(:group_token) { 'Work B' }

      it 'returns the citations of both, which display under one heading' do
        expect(result).to contain_exactly(citation_2, citation_3)
      end
    end

    context 'when the token is nil' do
      let(:group_token) { nil }

      it 'returns general citations tied neither to a work nor to a sub-heading' do
        expect(result).to eq([citation_general])
      end
    end

    context 'when the token names a general sub-heading' do
      let(:group_token) { "heading:#{group.id}" }

      it 'returns only that sub-heading\'s citations, not the same-titled work\'s' do
        expect(result).to eq([citation_grouped])
      end
    end

    context 'when the token is not found in any citation' do
      let(:group_token) { 'Bambarbia Kirgudu' }

      it 'returns empty array' do
        expect(result).to eq([])
      end
    end
  end

  describe '#intellectual_property' do
    it 'returns "copyrighted" when copyrighted is true' do
      person = build(:lex_person, copyrighted: true)
      expect(person.intellectual_property).to eq('copyrighted')
    end

    it 'returns "public_domain" when copyrighted is false' do
      person = build(:lex_person, copyrighted: false)
      expect(person.intellectual_property).to eq('public_domain')
    end

    it 'returns nil when copyrighted is nil' do
      person = build(:lex_person, copyrighted: nil)
      expect(person.intellectual_property).to be_nil
    end
  end

  describe '.max_citation_seqno_by_group_token' do
    subject(:result) do
      person.max_citation_seqno_by_group_token(group_token, exclude_citation_id: exclude_citation_id)
    end

    let(:person) { create(:lex_person) }
    let(:exclude_citation_id) { nil }

    let!(:citation_a_1) { create(:lex_citation, person: person, subject: 'Work A', seqno: 1) }
    let!(:citation_a_2) { create(:lex_citation, person: person, subject: 'Work A', seqno: 2) }
    let!(:citation_a_3) { create(:lex_citation, person: person, subject: 'Work A', seqno: 4) }

    context 'when there are citations with the given token' do
      let(:group_token) { 'Work A' }

      it 'returns the maximum seqno among those citations' do
        expect(result).to eq(4)
      end

      context 'when exclude_citation_id is provided' do
        let(:exclude_citation_id) { citation_a_3.id }

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

    context 'when the given token has no citations' do
      let(:group_token) { 'Work X' }

      it 'returns 0' do
        expect(result).to eq(0)
      end
    end

    context 'when a nil token is passed' do
      let(:group_token) { nil }

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

  describe '#group_citations_with_subject!' do
    subject(:call) { person.group_citations_with_subject!('ספרים:', 'ספרים') }

    let(:person) { create(:lex_person) }
    let!(:citation_1) { create(:lex_citation, person: person, subject: 'ספרים:', seqno: 1) }
    let!(:citation_2) { create(:lex_citation, person: person, subject: 'ספרים:', seqno: 2) }
    let!(:other) { create(:lex_citation, person: person, subject: 'מאמרים', seqno: 1) }

    it 'moves every citation under the heading into a sub-heading of that name' do
      expect(call).to eq(2)
      group = person.citation_groups.sole
      expect(group.title).to eq('ספרים')
      expect(group.citations).to contain_exactly(citation_1, citation_2)
    end

    it 'clears the legacy subject of the citations it groups, leaving the others alone' do
      call
      expect(citation_1.reload.subject).to be_nil
      expect(other.reload.subject).to eq('מאמרים')
    end

    it 'reuses an existing sub-heading of the same name' do
      group = create(:lex_citation_group, person: person, title: 'ספרים')
      expect { call }.not_to change(LexCitationGroup, :count)
      expect(citation_1.reload.citation_group).to eq(group)
    end
  end
end
