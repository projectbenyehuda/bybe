# frozen_string_literal: true

require 'rails_helper'

describe LexEntriesIndex do
  let(:lex_entry) { create(:lex_entry, :person, status: :published, title: 'Test Lexicon Entry') }

  before do
    clean_tables
    lex_entry.lex_item.update!(
      bio: '<img src="/files/lex/1/photo.jpg" width="200" /><span>נולד בוורשה</span><br />ועלה לארץ'
    )
    import_and_await(described_class, LexEntry.status_published)
  end

  after { Chewy.massacre }

  it 'indexes the bio as plain text rather than HTML' do
    fulltext = described_class.filter(term: { id: lex_entry.id }).first.fulltext

    expect(fulltext).to include('נולד בוורשה')
    expect(fulltext).to include('ועלה לארץ')
    expect(fulltext).not_to include('<img')
    expect(fulltext).not_to include('photo.jpg')
    expect(fulltext).not_to include('<span>')
  end

  # The hebrew_search analyzer runs on both sides of the comparison, so each pair below is
  # asserted in both directions rather than only from the plain spelling inwards.
  describe 'punctuation- and diacritic-insensitive matching' do
    subject(:matched_titles) do
      described_class.query(match: { title: { query: query } }).map(&:title)
    end

    let(:lex_entry) { create(:lex_entry, :person, status: :published, title: title) }

    context 'with niqqud in the title' do
      let(:title) { 'אמונה אֵלון' }

      context 'when queried without the niqqud' do
        let(:query) { 'אמונה אלון' }

        it { is_expected.to contain_exactly title }
      end

      context 'when queried with the niqqud' do
        let(:query) { 'אמונה אֵלון' }

        it { is_expected.to contain_exactly title }
      end
    end

    context 'with a maqaf in the title' do
      let(:title) { 'בן־ציון בן־משה' }

      context 'when queried with spaces instead' do
        let(:query) { 'בן ציון בן משה' }

        it { is_expected.to contain_exactly title }
      end

      context 'when queried with the maqaf' do
        let(:query) { 'בן־ציון בן־משה' }

        it { is_expected.to contain_exactly title }
      end
    end

    context 'with gershayim in the title' do
      let(:title) { 'יואב כ״ץ' }

      context 'when queried without them' do
        let(:query) { 'כץ' }

        it 'matches, because gershayim are dropped rather than treated as a word break' do
          expect(matched_titles).to contain_exactly title
        end
      end

      context 'when queried with them' do
        let(:query) { 'כ״ץ' }

        it { is_expected.to contain_exactly title }
      end
    end

    context 'when the query matches nothing' do
      let(:title) { 'יואב כ״ץ' }
      let(:query) { 'שרה לוי' }

      it { is_expected.to be_empty }
    end
  end
end
