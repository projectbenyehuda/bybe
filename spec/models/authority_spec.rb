# frozen_string_literal: true

require 'rails_helper'

describe Authority do
  describe 'validations' do
    it 'considers empty Authority invalid' do
      a = described_class.new
      expect(a).not_to be_valid
    end

    it 'considers Authority with all mandatory fields filled as valid' do
      a = described_class.new(
        name: Faker::Artist.name,
        intellectual_property: :public_domain,
        person: create(:person)
      )
      expect(a).to be_valid
    end

    describe 'uncollected works collection type validation' do
      let(:authority) { build(:authority, uncollected_works_collection: uncollected_works_collection) }

      context 'when uncollected collection is not set' do
        let(:uncollected_works_collection) { nil }

        it { expect(authority).to be_valid }
      end

      context 'when uncollected collection is set and has uncollected type' do
        let(:uncollected_works_collection) { create(:collection, :uncollected) }

        it { expect(authority).to be_valid }
      end

      context 'when uncollected collection is set but has wrong type' do
        let(:uncollected_works_collection) { create(:collection) }

        it 'fails validation' do
          expect(authority).not_to be_valid
          expect(authority.errors[:uncollected_works_collection]).to eq [
            I18n.t('activerecord.errors.models.authority.wrong_collection_type', expected_type: :uncollected)
          ]
        end
      end
    end

    describe '.validate_linked_authority' do
      subject(:result) { authority.valid? }

      let(:authority) do
        described_class.new(
          name: Faker::Artist.name,
          intellectual_property: :public_domain,
          person: person,
          corporate_body: corporate_body
        )
      end

      context 'when person and corporate body are nil' do
        let(:corporate_body) { nil }
        let(:person) { nil }

        it 'fails' do
          expect(result).to be false
          expect(authority.errors[:base]).to contain_exactly(
            I18n.t('activerecord.errors.models.authority.attributes.base.no_linked_authority')
          )
        end
      end

      context 'when person and corporate body both present' do
        let(:corporate_body) { create(:corporate_body) }
        let(:person) { create(:person) }

        it 'fails' do
          expect(result).to be false
          expect(authority.errors[:base]).to contain_exactly(
            I18n.t('activerecord.errors.models.authority.attributes.base.multiple_linked_authorities')
          )
        end
      end

      context 'when person present' do
        let(:corporate_body) { nil }
        let(:person) { create(:person) }

        it { is_expected.to be_truthy }
      end

      context 'when corporate_body present' do
        let(:corporate_body) { create(:corporate_body) }
        let(:person) { nil }

        it { is_expected.to be_truthy }
      end
    end

    describe '.wikidata_uri' do
      subject(:result) { authority.valid? }

      let(:authority) { build(:authority, wikidata_uri: value) }

      context 'when value is blank' do
        let(:value) { '  ' }

        it 'succeed but sets value to nil' do
          expect(result).to be_truthy
          expect(authority.wikidata_uri).to be_nil
        end
      end

      context 'when uri has wrong format' do
        let(:value) { 'http://wikidata.org/wiki/q1234' } # wrong protocol

        it { is_expected.to be false }
      end

      context 'when uri is correct has wrong case' do
        let(:value) { ' HTTPS://wikidata.org/WIKI/q1234  ' }

        it 'normalizes it by adjusting case and removing leading/trailing whitespaces' do
          expect(result).to be_truthy
          expect(authority.wikidata_uri).to eq 'https://wikidata.org/wiki/Q1234'
        end
      end

      context 'when uri is correct but id is not numeric' do
        let(:value) { 'https://wikidata.org/wiki/Q1234A' }

        it { is_expected.to be false }
      end
    end
  end

  describe 'instance methods' do
    let(:authority) { create(:authority) }

    describe '.all_genres' do
      subject { authority.all_genres }

      before do
        create(:manifestation, author: authority, genre: 'poetry')
        create(:manifestation, author: authority, genre: 'poetry')
        create(:manifestation, illustrator: authority, genre: 'fables') # illustrated works should not be included
        create(:manifestation, translator: authority, orig_lang: 'ru', genre: 'article')
        create(:manifestation, translator: authority, orig_lang: 'ru', genre: 'memoir')
        create(:manifestation, editor: authority, genre: 'prose') # edited works should not be included
      end

      it { is_expected.to eq %w(article memoir poetry) }
    end

    describe '.most_read' do
      subject { authority.most_read(limit).pluck(:id) }

      let!(:manifestation_1) { create(:manifestation, author: authority, impressions_count: 10, genre: :fables) }
      let!(:manifestation_2) { create(:manifestation, author: authority, impressions_count: 20, genre: :memoir) }
      let!(:manifestation_3) { create(:manifestation, author: authority, impressions_count: 30, genre: :article) }

      context 'when limit is less than total number of works' do
        let(:limit) { 2 }

        it { is_expected.to eq [manifestation_3.id, manifestation_2.id] }
      end

      context 'when limit is equal to total number of works' do
        let(:limit) { 3 }

        it { is_expected.to eq [manifestation_3.id, manifestation_2.id, manifestation_1.id] }
      end

      context 'when limit is bigger than total number of works' do
        let(:limit) { 4 }

        it { is_expected.to eq [manifestation_3.id, manifestation_2.id, manifestation_1.id] }
      end
    end

    describe '.any_hebrew_works?' do
      subject { authority.any_hebrew_works? }

      context 'when authority has no works' do
        it { is_expected.to be false }
      end

      context 'when authority has original and translated works but not in hebrew' do
        before do
          create(:manifestation, language: 'he', orig_lang: 'de', author: authority)
          create(:manifestation, language: 'en', orig_lang: 'he', translator: authority)
        end

        it { is_expected.to be false }
      end

      context 'when authority has original work in hebrew' do
        before do
          create(:manifestation, language: 'de', orig_lang: 'he', author: authority)
        end

        it { is_expected.to be_truthy }
      end

      context 'when authority has translated work in hebrew' do
        before do
          create(:manifestation, language: 'he', orig_lang: 'ru', translator: authority)
        end

        it { is_expected.to be_truthy }
      end
    end

    describe '.any_non_hebrew_works?' do
      subject { authority.any_non_hebrew_works? }

      context 'when authority has no works' do
        it { is_expected.to be false }
      end

      context 'when authority has non-hebrew work' do
        before do
          create(:manifestation, orig_lang: 'ru', author: authority)
        end

        it { is_expected.to be_truthy }
      end

      context 'when authority has hebrew work' do
        before do
          create(:manifestation, orig_lang: 'he', author: authority)
        end

        it { is_expected.to be false }
      end
    end

    describe '.latest_stuff' do
      subject(:latest_stuff) { authority.latest_stuff }

      let!(:original_work) { create(:manifestation, author: authority) }
      let!(:translated_work) { create(:manifestation, orig_lang: 'ru', translator: authority) }
      let!(:edited_work) { create(:manifestation, orig_lang: 'ru', editor: authority) }

      it 'returns latest original and translated works' do
        expect(latest_stuff).to contain_exactly(original_work, translated_work)
      end

      context 'when more than 20 records present' do
        before do
          create_list(:manifestation, 25, author: authority)
        end

        it 'returns first 20 records only' do
          expect(latest_stuff.length).to eq 20
        end
      end
    end

    describe '.cached_works_count' do
      subject { authority.cached_works_count }

      before do
        create(:manifestation, author: authority) # should be counted
        create(:manifestation, editor: authority) # should be counted
        create(:manifestation, orig_lang: 'de', author: authority, translator: authority) # should be counted only once
        create(:manifestation, author: authority, status: :unpublished) # should not be counted
        create(:manifestation, editor: authority, status: :unpublished) # should not be counted
        create(:manifestation)                                          # should not be counted
      end

      it { is_expected.to eq 3 }
    end

    describe '.all_works_by_title' do
      subject { authority.all_works_by_title(title) }

      let(:title) { 'search term' }
      let!(:translated_work) do
        create(
          :manifestation,
          title: "translated #{title} work", language: 'he', orig_lang: 'ru', translator: authority
        )
      end
      let!(:original_work) do
        create(:manifestation, title: "original #{title} work", author: authority)
      end

      # this item should not be duplicated
      let!(:original_and_translated_work) do
        create(:manifestation,
               title: "original translated #{title} work", language: 'he', orig_lang: 'ru',
               author: authority, translator: authority)
      end

      before do
        # those records has different title
        create_list(:manifestation, 2, language: 'he', orig_lang: 'ru', translator: authority)
        create_list(:manifestation, 2, author: authority)
      end

      it { is_expected.to contain_exactly(original_work, translated_work, original_and_translated_work) }
    end

    describe '.manifestations' do
      let!(:as_author) { create(:manifestation, author: authority) }
      let!(:as_translator) { create(:manifestation, translator: authority, orig_lang: 'en') }
      let!(:as_author_and_illustrator) { create(:manifestation, author: authority, illustrator: authority) }
      let!(:as_author_unpublished) { create(:manifestation, author: authority, status: :unpublished) }
      let!(:as_illustrator_on_expression_level) do
        create(:manifestation).tap do |manifestation|
          manifestation.expression.involved_authorities.create!(role: :illustrator, authority: authority)
        end
      end

      before do
        create_list(:manifestation, 5)
      end

      context 'when single role is passed' do
        it 'returns all manifestations where authority has given role, including unpublished' do
          expect(authority.manifestations(:author)).to contain_exactly(
            as_author,
            as_author_unpublished,
            as_author_and_illustrator
          )
          expect(authority.manifestations(:translator)).to eq [as_translator]
          expect(authority.manifestations(:illustrator)).to contain_exactly(
            as_author_and_illustrator,
            as_illustrator_on_expression_level
          )
          expect(authority.manifestations(:editor)).to be_empty
        end
      end

      context 'when several roles are passed' do
        it 'returns all manifestations where authority has given role, including unpublished' do
          expect(authority.manifestations(:author, :editor)).to contain_exactly(
            as_author,
            as_author_unpublished,
            as_author_and_illustrator
          )

          expect(authority.manifestations(:author, :translator)).to contain_exactly(
            as_author,
            as_author_unpublished,
            as_author_and_illustrator,
            as_translator
          )

          expect(authority.manifestations(:translator, :illustrator)).to contain_exactly(
            as_translator,
            as_author_and_illustrator,
            as_illustrator_on_expression_level
          )

          expect(authority.manifestations(:editor, :other)).to be_empty
        end
      end

      context 'when no roles are passed' do
        it 'returns all manifestations where authority has any role, including unpublished' do
          expect(authority.manifestations).to contain_exactly(
            as_author,
            as_author_unpublished,
            as_author_and_illustrator,
            as_translator,
            as_illustrator_on_expression_level
          )
        end
      end
    end

    describe '.published_manifestations' do
      let!(:as_author) { create(:manifestation, author: authority) }
      let!(:as_translator) { create(:manifestation, translator: authority, orig_lang: 'en') }
      let!(:as_author_and_illustrator) { create(:manifestation, author: authority, illustrator: authority) }
      let!(:as_author_unpublished) { create(:manifestation, author: authority, status: :unpublished) }

      before do
        create_list(:manifestation, 5)
      end

      it 'works correctly and ignores unpublished works' do
        expect(authority.published_manifestations).to contain_exactly(
          as_author, as_translator, as_author_and_illustrator
        )
        expect(authority.published_manifestations(:author)).to contain_exactly(
          as_author, as_author_and_illustrator
        )
        expect(authority.published_manifestations(:translator, :illustrator)).to contain_exactly(
          as_translator, as_author_and_illustrator
        )
        expect(authority.published_manifestations(:editor)).to be_empty
      end
    end

    describe '.original_works_by_genre' do
      subject(:result) { authority.original_works_by_genre }

      let!(:fables) { create_list(:manifestation, 5, genre: :fables, author: authority) }
      let!(:poetry) { create_list(:manifestation, 2, genre: :poetry, author: authority) }

      it 'works correctly' do
        expect(result).to eq({
                               'article' => [],
                               'drama' => [],
                               'fables' => fables,
                               'letters' => [],
                               'lexicon' => [],
                               'memoir' => [],
                               'poetry' => poetry,
                               'prose' => [],
                               'reference' => []
                             })
      end
    end

    describe '.translations_by_genre' do
      subject(:result) { authority.translations_by_genre }

      let!(:memoirs) { create_list(:manifestation, 5, genre: :memoir, orig_lang: :ru, translator: authority) }
      let!(:poetry) { create_list(:manifestation, 2, genre: :poetry, orig_lang: :en, translator: authority) }
      let!(:articles) { create_list(:manifestation, 3, genre: :article, orig_lang: :de, translator: authority) }

      it 'works correctly' do
        expect(result).to eq({
                               'article' => articles,
                               'drama' => [],
                               'fables' => [],
                               'letters' => [],
                               'lexicon' => [],
                               'memoir' => memoirs,
                               'poetry' => poetry,
                               'prose' => [],
                               'reference' => []
                             })
      end
    end
  end
end
