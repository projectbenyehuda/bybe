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

  describe '#link_broken?' do
    subject { build(:lex_citation, link_checked_at: checked_at, link_http_status: status).link_broken? }

    context 'when never checked (checked_at nil)' do
      let(:checked_at) { nil }
      let(:status) { nil }

      it { is_expected.to be false }
    end

    context 'when checked and unreachable (status nil)' do
      let(:checked_at) { Time.current }
      let(:status) { nil }

      it { is_expected.to be true }
    end

    context 'when checked and healthy (status 200)' do
      let(:checked_at) { Time.current }
      let(:status) { 200 }

      it { is_expected.to be false }
    end

    context 'when checked and 404' do
      let(:checked_at) { Time.current }
      let(:status) { 404 }

      it { is_expected.to be true }
    end

    context 'when checked and 500' do
      let(:checked_at) { Time.current }
      let(:status) { 500 }

      it { is_expected.to be true }
    end

    context 'when link is a local file path (e.g. /files/lex/...)' do
      subject do
        build(:lex_citation, link: '/files/lex/7635/article.pdf',
                             link_checked_at: Time.current, link_http_status: nil).link_broken?
      end

      it { is_expected.to be false }
    end

    context 'when link is a local internal URL (e.g. /lex/entries/...)' do
      subject do
        build(:lex_citation, link: '/lex/entries/1234#no5',
                             link_checked_at: Time.current, link_http_status: nil).link_broken?
      end

      it { is_expected.to be false }
    end
  end
end
