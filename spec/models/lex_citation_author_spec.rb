# frozen_string_literal: true

require 'rails_helper'

describe LexCitationAuthor do
  describe 'validations' do
    subject(:result) { author.valid? }

    let(:lex_person) { create(:lex_entry, :person).lex_item }
    let(:citation) { build(:lex_citation, person: lex_person) }

    describe 'name presence/absence' do
      context 'without entry' do
        let(:author) { build(:lex_citation_author, citation: citation, entry: nil, name: nil, link: nil) }

        it 'requires name' do
          expect(result).to be false
          expect(author.errors[:name]).to be_present
        end
      end

      context 'with entry and no name' do
        let(:entry) { create(:lex_entry, :person) }
        let(:author) { build(:lex_citation_author, citation: citation, entry: entry, name: nil, link: nil) }

        it { is_expected.to be_truthy }
      end

      context 'with entry and name' do
        let(:entry) { create(:lex_entry, :person) }
        let(:author) { build(:lex_citation_author, citation: citation, entry: entry, name: 'John', link: nil) }

        it { is_expected.to be_truthy }
      end
    end

    describe 'link must be absent when entry is provided' do
      let(:entry) { create(:lex_entry, :person) }
      let(:author) { build(:lex_citation_author, citation: citation, entry: entry, name: nil, link: 'http://example.com') }

      it 'fails with a custom validation message' do
        expect(result).to be false
        expect(author.errors[:link]).to include(
          I18n.t('activerecord.errors.models.lex_citation_author.attributes.link.link_with_entry_error')
        )
      end
    end

    describe 'entry must be a Person entry' do
      context 'when entry has a LexPerson lex_item' do
        let(:entry) { create(:lex_entry, :person) }
        let(:author) { build(:lex_citation_author, citation: citation, entry: entry, name: nil, link: nil) }

        it { is_expected.to be_truthy }
      end

      context 'when entry has a LexFile with entrytype person' do
        let(:lex_file) { create(:lex_file, :person) }
        let(:author) do
          build(:lex_citation_author, citation: citation, entry: lex_file.lex_entry, name: nil, link: nil)
        end

        it { is_expected.to be_truthy }
      end

      context 'when entry has a non-person lex_item' do
        let(:entry) { create(:lex_entry, :publication) }
        let(:author) { build(:lex_citation_author, citation: citation, entry: entry, name: nil, link: nil) }

        it 'fails with a validation message' do
          expect(result).to be false
          expect(author.errors[:entry]).to include(
            I18n.t('activerecord.errors.models.lex_citation_author.attributes.entry.not_a_person')
          )
        end
      end
    end
  end

  describe '.normalize_name' do
    subject { described_class.normalize_name(name) }

    context 'when the name is in "lastname, firstname" form' do
      let(:name) { 'איזיקוביץ, גילי' }

      it { is_expected.to eq('גילי איזיקוביץ') }
    end

    context 'when the surname is followed by several given names' do
      let(:name) { 'ביאליק, חיים נחמן' }

      it { is_expected.to eq('חיים נחמן ביאליק') }
    end

    context 'when the name has no comma' do
      let(:name) { 'מירה הרשקו' }

      it { is_expected.to eq('מירה הרשקו') }
    end

    context 'when the name has a trailing comma and nothing after it' do
      let(:name) { 'ביאליק,' }

      it { is_expected.to eq('ביאליק') }
    end

    context 'when the name carries stray whitespace' do
      let(:name) { "  איזיקוביץ,\n גילי  " }

      it { is_expected.to eq('גילי איזיקוביץ') }
    end

    context 'when the name is blank' do
      let(:name) { '' }

      it { is_expected.to be_nil }
    end
  end

  describe '.matchable_names' do
    subject(:matches) { described_class.matchable_names(authors) }

    let(:lex_person) { create(:lex_entry, :person).lex_item }
    let(:citation) { create(:lex_citation, person: lex_person, authors_count: 0) }

    def author_named(name)
      create(:lex_citation_author, citation: citation, name: name, link: nil)
    end

    context 'when a person entry is titled exactly like the normalized name' do
      before { create(:lex_entry, :person, title: 'גילי איזיקוביץ') }

      let(:authors) { [author_named('איזיקוביץ, גילי')] }

      it { is_expected.to contain_exactly('גילי איזיקוביץ') }
    end

    context 'when the only entry with that title is a publication' do
      before { create(:lex_entry, :publication, title: 'גילי איזיקוביץ') }

      let(:authors) { [author_named('איזיקוביץ, גילי')] }

      it { is_expected.to be_empty }
    end

    context 'when the entry is a not-yet-migrated person file' do
      before { create(:lex_file, :person, entry_status: :raw, title: 'גילי איזיקוביץ') }

      let(:authors) { [author_named('איזיקוביץ, גילי')] }

      it { is_expected.to contain_exactly('גילי איזיקוביץ') }
    end

    context 'when no entry carries that title' do
      let(:authors) { [author_named('איזיקוביץ, גילי')] }

      it { is_expected.to be_empty }
    end

    context 'when the author is already linked to an entry' do
      let(:entry) { create(:lex_entry, :person, title: 'גילי איזיקוביץ') }
      let(:authors) do
        [create(:lex_citation_author, citation: citation, entry: entry, name: 'איזיקוביץ, גילי', link: nil)]
      end

      it 'does not offer a match for it' do
        expect(matches).to be_empty
      end
    end

    context 'with several authors' do
      before do
        create(:lex_entry, :person, title: 'גילי איזיקוביץ')
        create(:lex_entry, :person, title: 'חיים נחמן ביאליק')
      end

      let(:authors) do
        [author_named('איזיקוביץ, גילי'), author_named('ביאליק, חיים נחמן'), author_named('לא, קיים')]
      end

      it 'reports only the names an entry exists for' do
        expect(matches).to contain_exactly('גילי איזיקוביץ', 'חיים נחמן ביאליק')
      end
    end

    context 'with no authors at all' do
      let(:authors) { [] }

      it 'returns an empty set without hitting the database' do
        allow(LexEntry).to receive(:person_type)
        expect(matches).to be_empty
        expect(LexEntry).not_to have_received(:person_type)
      end
    end
  end
end
