# frozen_string_literal: true

require 'rails_helper'

describe LexCitationAuthor do
  describe '#display_name' do
    subject(:display_name) { author.display_name }

    let(:lex_person) { create(:lex_entry, :person).lex_item }
    let(:citation) { build(:lex_citation, person: lex_person) }
    let(:entry) { create(:lex_entry, :person, title: 'תלמה אדמון (1949)') }

    context 'when a legacy name is present (migrated author)' do
      let(:author) { build(:lex_citation_author, citation: citation, entry: entry, name: 'אדמון, ת.', link: nil) }

      it 'prefers the stored name' do
        expect(display_name).to eq('אדמון, ת.')
      end
    end

    context 'when only an entry is present (manually added author)' do
      let(:author) { build(:lex_citation_author, citation: citation, entry: entry, name: nil, link: nil) }

      it 'displays the entry title surname-first, like migrated authors' do
        expect(display_name).to eq('אדמון, תלמה')
      end
    end
  end

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
end
