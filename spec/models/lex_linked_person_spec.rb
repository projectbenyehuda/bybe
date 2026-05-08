# frozen_string_literal: true

require 'rails_helper'

describe LexLinkedPerson do
  describe 'validation' do
    subject(:result) { linked_person.valid? }

    describe 'name presence' do
      context 'when name is provided' do
        let(:linked_person) { build(:lex_linked_person, name: 'Test') }

        it { is_expected.to be true }
      end

      context 'when name is not provided' do
        let(:linked_person) { build(:lex_linked_person, name: nil) }

        it 'fails' do
          expect(result).to be false
          expect(linked_person.errors[:name]).to be_present
        end
      end
    end

    describe 'person_entry type' do
      let(:linked_person) { build(:lex_linked_person, name: Faker.name, person_entry: entry) }

      context 'when person_entry is an ingested Person Entry' do
        let(:entry) { create(:lex_entry, :person) }

        it { is_expected.to be true }
      end

      context 'when entry is an ingested Non-Person Entry' do
        let(:entry) { create(:lex_entry, :publication) }

        it 'fails' do
          expect(result).to be false
          expect(linked_person.errors[:person_entry]).to include(
            I18n.t('activerecord.errors.models.lex_linked_person.attributes.person_entry.not_a_person')
          )
        end
      end

      context 'when entry is a not-ingested Person Entry' do
        let(:entry) { create(:lex_file, :person).lex_entry }

        it { is_expected.to be true }
      end

      context 'when entry is a not-ingested Non-person Entry' do
        let(:entry) { create(:lex_file, :publication, entry_status: :raw).lex_entry }

        it 'fails' do
          expect(result).to be false
          expect(linked_person.errors[:person_entry]).to include(
            I18n.t('activerecord.errors.models.lex_linked_person.attributes.person_entry.not_a_person')
          )
        end
      end
    end
  end
end
