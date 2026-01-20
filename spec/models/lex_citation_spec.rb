# frozen_string_literal: true

require 'rails_helper'

describe LexCitation do
  describe 'validations' do
    subject(:result) { citation.valid? }

    describe 'person_work association validation' do
      let(:person) { create(:lex_entry, :person).lex_item }
      let(:citation) { build(:lex_citation, person: person, person_work: person_work) }

      context 'when person_work is nil' do
        let(:person_work) { nil }

        it { is_expected.to be_truthy }
      end

      context 'when person_work belongs to same person' do
        let(:person_work) { create(:lex_person_work, person: person) }

        it { is_expected.to be_truthy }
      end

      context 'when person_work belongs to different person' do
        let(:other_person) { create(:lex_entry, :person).lex_item }
        let(:person_work) { create(:lex_person_work, person: other_person) }

        it 'fails with a validation message' do
          expect(result).to be false
          expect(citation.errors[:person_work]).to include(
            I18n.t('activerecord.errors.models.lex_citation.attributes.person_work.belongs_to_different_person')
          )
        end
      end
    end
  end
end
