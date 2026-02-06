# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

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

      context 'when input is a plain number' do
        let(:value) { '123' }

        it 'transforms it into a canonical Wikidata URL' do
          expect(result).to be_truthy
          expect(authority.wikidata_uri).to eq 'https://wikidata.org/wiki/Q123'
        end
      end

      context 'when input is a plain number with whitespace' do
        let(:value) { '  456  ' }

        it 'transforms it into a canonical Wikidata URL' do
          expect(result).to be_truthy
          expect(authority.wikidata_uri).to eq 'https://wikidata.org/wiki/Q456'
        end
      end

      context 'when input is Q-prefixed (uppercase)' do
        let(:value) { 'Q789' }

        it 'transforms it into a canonical Wikidata URL' do
          expect(result).to be_truthy
          expect(authority.wikidata_uri).to eq 'https://wikidata.org/wiki/Q789'
        end
      end

      context 'when input is Q-prefixed (lowercase)' do
        let(:value) { 'q321' }

        it 'transforms it into a canonical Wikidata URL with uppercase Q' do
          expect(result).to be_truthy
          expect(authority.wikidata_uri).to eq 'https://wikidata.org/wiki/Q321'
        end
      end

      context 'when input is Q-prefixed with whitespace' do
        let(:value) { '  Q654  ' }

        it 'transforms it into a canonical Wikidata URL' do
          expect(result).to be_truthy
          expect(authority.wikidata_uri).to eq 'https://wikidata.org/wiki/Q654'
        end
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

    describe 'responsibility_statement update on name change' do
      let(:author) { create(:authority, name: 'Original Name') }
      let!(:manifestation) { create(:manifestation, author: author) }

      around do |example|
        Sidekiq::Testing.inline! do
          example.run
        end
      end

      it 'updates manifestation responsibility_statement when authority name changes' do
        expect do
          author.update!(name: 'New Name')
          manifestation.reload
        end.to change { manifestation.responsibility_statement }
      end

      it 'includes the new name in responsibility_statement' do
        author.update!(name: 'Updated Name')
        manifestation.reload
        expect(manifestation.responsibility_statement).to include('Updated Name')
      end
    end

    describe '#update_other_designation' do
      let(:authority) { create(:authority, name: 'פִּתְאֹם') }

      it 'updates other_designation with forms from AlternateHebrewForms service' do
        authority.update_column(:other_designation, nil)
        authority.update_other_designation
        expect(authority.other_designation).to eq('פתאם; פיתאום')
      end

      it 'preserves existing other designation and adds new ones' do
        authority.update_column(:other_designation, 'עוד משהו')
        authority.update_other_designation
        expect(authority.other_designation).to eq('עוד משהו; פתאם; פיתאום')
      end

      it 'removes duplicates when combining existing and new alternate forms' do
        authority.update_column(:other_designation, 'פיתאום')
        authority.update_other_designation
        expect(authority.other_designation).to eq('פיתאום; פתאם')
      end

      it 'handles empty existing other_designation' do
        authority.update_column(:other_designation, '')
        authority.update_other_designation
        expect(authority.other_designation).to eq('פתאם; פיתאום')
      end

      it 'handles nil existing other_designation' do
        authority.update_column(:other_designation, nil)
        authority.update_other_designation
        expect(authority.other_designation).to eq('פתאם; פיתאום')
      end

      context 'when other_designation has some other (user-provided) names' do
        it 'preserves existing other_designation' do
          authority.update_column(:other_designation, 'משהו אחר')
          authority.update_other_designation
          expect(authority.other_designation).to eq('משהו אחר; פתאם; פיתאום')
        end
      end
    end

    describe 'before_save callbacks' do
      let(:authority) { build(:authority, name: 'מִבְחַר שִירִים') }

      describe 'update_other_designation callback' do
        it 'is triggered when name changes' do
          expect(authority).to receive(:update_other_designation)
          authority.save!
        end

        it 'is not triggered when name does not change' do
          authority.save!
          authority.reload
          expect(authority).not_to receive(:update_other_designation)
          authority.update!(other_designation: 'new designation')
        end

        it 'is triggered when name changes on update' do
          authority.save!
          authority.reload
          expect(authority).to receive(:update_other_designation)
          authority.update!(name: 'שם חדש')
        end
      end

      describe 'normalize_sort_name callback' do
        it 'is triggered on save' do
          allow(authority).to receive(:normalize_sort_name).and_call_original
          authority.save!
          expect(authority).to have_received(:normalize_sort_name)
        end

        it 'is triggered on update' do
          authority.save!
          authority.reload
          allow(authority).to receive(:normalize_sort_name).and_call_original
          authority.update!(sort_name: 'some-name')
          expect(authority).to have_received(:normalize_sort_name)
        end
      end
    end

    describe '#normalize_sort_name' do
      let(:authority) { build(:authority) }

      it 'replaces Hebrew maqaf (־) with space' do
        authority.sort_name = 'חנה־לאה'
        authority.normalize_sort_name
        expect(authority.sort_name).to eq('חנה לאה')
      end

      it 'replaces regular hyphen (-) with space' do
        authority.sort_name = 'Smith-Jones'
        authority.normalize_sort_name
        expect(authority.sort_name).to eq('Smith Jones')
      end

      it 'replaces en dash (–) with space' do
        authority.sort_name = 'Name–Other'
        authority.normalize_sort_name
        expect(authority.sort_name).to eq('Name Other')
      end

      it 'replaces em dash (—) with space' do
        authority.sort_name = 'Name—Other'
        authority.normalize_sort_name
        expect(authority.sort_name).to eq('Name Other')
      end

      it 'replaces multiple types of dashes in one string' do
        authority.sort_name = 'חנה־לאה–Smith-Jones—Test'
        authority.normalize_sort_name
        expect(authority.sort_name).to eq('חנה לאה Smith Jones Test')
      end

      it 'does nothing when sort_name is nil' do
        authority.sort_name = nil
        expect { authority.normalize_sort_name }.not_to raise_error
        expect(authority.sort_name).to be_nil
      end

      it 'does nothing when sort_name is empty' do
        authority.sort_name = ''
        authority.normalize_sort_name
        expect(authority.sort_name).to eq('')
      end

      it 'normalizes sort_name on save' do
        authority.sort_name = 'Test-Name'
        authority.save!
        expect(authority.sort_name).to eq('Test Name')
      end

      it 'normalizes sort_name on update' do
        authority.save!
        authority.update!(sort_name: 'חנה־לאה')
        expect(authority.reload.sort_name).to eq('חנה לאה')
      end
    end
  end

  describe 'scopes' do
    describe '.featurable' do
      let!(:featurable_authority) { create(:authority, do_not_feature: false) }
      let!(:non_featurable_authority) { create(:authority, do_not_feature: true) }

      it 'includes authorities with do_not_feature false' do
        expect(described_class.featurable).to include(featurable_authority)
      end

      it 'excludes authorities with do_not_feature true' do
        expect(described_class.featurable).not_to include(non_featurable_authority)
      end
    end
  end

  describe '.popular_authors' do
    before do
      # Clear cache before test
      Rails.cache.delete('m_popular_authors')
    end

    let!(:popular_authority) { create(:authority) }
    let!(:popular_non_featurable) { create(:authority, do_not_feature: true) }
    let!(:unpopular_authority) { create(:authority) }

    before do
      # Create view events for popular authorities
      20.times do
        create(:ahoy_event, :with_item, name: 'view', item: popular_authority, time: 1.week.ago)
      end
      15.times do
        create(:ahoy_event, :with_item, name: 'view', item: popular_non_featurable, time: 1.week.ago)
      end
      5.times do
        create(:ahoy_event, :with_item, name: 'view', item: unpopular_authority, time: 1.week.ago)
      end
    end

    it 'includes popular authorities that are featurable' do
      result = described_class.popular_authors
      expect(result).to include(popular_authority)
    end

    it 'excludes popular authorities with do_not_feature flag' do
      result = described_class.popular_authors
      expect(result).not_to include(popular_non_featurable)
    end
  end
end
