# frozen_string_literal: true

require 'rails_helper'

describe SearchManifestations do
  after do
    Chewy.massacre
  end

  describe 'filtering' do
    subject!(:result) { described_class.call(sort_by, sort_dir, filter) }

    let(:sort_by) { 'alphabetical' }
    let(:sort_dir) { 'asc' }

    describe 'by genres' do
      let(:filter) { { 'genres' => genres } }

      context 'when single genre specified' do
        let(:genres) { %w[poetry] }
        let(:poetry_1) { create(:manifestation, genre: 'poetry') }
        let(:poetry_2) { create(:manifestation, genre: 'poetry') }
        let(:prose_1) { create(:manifestation, genre: 'prose') }
        let(:drama_1) { create(:manifestation, genre: 'drama') }

        before do
          Chewy.strategy(:atomic) do
            poetry_1
            poetry_2
            prose_1
            drama_1
          end
        end

        it 'returns all texts where genre is equal to provided value' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(poetry_1.id, poetry_2.id)
        end
      end

      context 'when multiple genres specified' do
        let(:genres) { %w[poetry article] }
        let(:poetry) { create(:manifestation, genre: 'poetry') }
        let(:article) { create(:manifestation, genre: 'article') }
        let(:prose) { create(:manifestation, genre: 'prose') }

        before do
          Chewy.strategy(:atomic) do
            poetry
            article
            prose
          end
        end

        it 'returns all texts where genre is included in provided list' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(poetry.id, article.id)
        end
      end
    end

    describe 'by periods' do
      let(:filter) { { 'periods' => periods } }

      context 'when single period specified' do
        let(:periods) { %w[ancient] }
        let(:ancient_1) { create(:manifestation, period: 'ancient') }
        let(:ancient_2) { create(:manifestation, period: 'ancient') }
        let(:modern) { create(:manifestation, period: 'modern') }
        let(:medieval) { create(:manifestation, period: 'medieval') }

        before do
          Chewy.strategy(:atomic) do
            ancient_1
            ancient_2
            modern
            medieval
          end
        end

        it 'returns all texts where period is equal to provided value' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(ancient_1.id, ancient_2.id)
        end
      end

      context 'when multiple periods specified' do
        let(:periods) { %w[ancient revival] }
        let(:ancient) { create(:manifestation, period: 'ancient') }
        let(:revival) { create(:manifestation, period: 'revival') }
        let(:modern) { create(:manifestation, period: 'modern') }

        before do
          Chewy.strategy(:atomic) do
            ancient
            revival
            modern
          end
        end

        it 'returns all texts where period is included in provided list' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(ancient.id, revival.id)
        end
      end
    end

    describe 'by intellectual property types' do
      let(:types) { %w[public_domain unknown] }
      let(:filter)  { { 'intellectual_property_types' => types } }
      let(:public_domain) { create(:manifestation, intellectual_property: 'public_domain') }
      let(:unknown) { create(:manifestation, intellectual_property: 'unknown') }
      let(:copyrighted) { create(:manifestation, intellectual_property: 'copyrighted') }

      before do
        Chewy.strategy(:atomic) do
          public_domain
          unknown
          copyrighted
        end
      end

      it 'returns all works with given intellectual property types' do
        result_ids = result.map(&:id)
        expect(result_ids).to contain_exactly(public_domain.id, unknown.id)
      end
    end

    describe 'by author_genders' do
      let(:filter) { { 'author_genders' => author_genders } }

      context('when single value provided') do
        let(:author_genders) { [:male] }
        let(:male_author) { create(:authority, gender: 'male') }
        let(:female_author) { create(:authority, gender: 'female') }
        let(:male_1) { create(:manifestation, author: male_author) }
        let(:male_2) { create(:manifestation, author: male_author) }
        let(:female) { create(:manifestation, author: female_author) }

        before do
          Chewy.strategy(:atomic) do
            male_1
            male_2
            female
          end
        end

        it 'returns all records where author has given gender' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(male_1.id, male_2.id)
        end
      end

      context('when multiple values provided') do
        let(:author_genders) { %i[male female unknown] }
        let(:male_author) { create(:authority, gender: 'male') }
        let(:female_author) { create(:authority, gender: 'female') }
        let(:unknown_author) { create(:authority, gender: 'unknown') }
        let(:other_author) { create(:authority, gender: 'other') }
        let(:male) { create(:manifestation, author: male_author) }
        let(:female) { create(:manifestation, author: female_author) }
        let(:unknown) { create(:manifestation, author: unknown_author) }
        let(:other) { create(:manifestation, author: other_author) }

        before do
          Chewy.strategy(:atomic) do
            male
            female
            unknown
            other
          end
        end

        it 'returns all records where author has any of given genders' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(male.id, female.id, unknown.id)
        end
      end
    end

    describe 'by translator_genders' do
      let(:filter) { { 'translator_genders' => translator_genders } }

      context('when single value provided') do
        let(:translator_genders) { [:female] }
        let(:female_translator) { create(:authority, gender: 'female') }
        let(:male_translator) { create(:authority, gender: 'male') }
        let(:female_1) { create(:manifestation, translator: female_translator, orig_lang: 'en') }
        let(:female_2) { create(:manifestation, translator: female_translator, orig_lang: 'en') }
        let(:male) { create(:manifestation, translator: male_translator, orig_lang: 'en') }

        before do
          Chewy.strategy(:atomic) do
            female_1
            female_2
            male
          end
        end

        it 'returns all records where translator has given gender' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(female_1.id, female_2.id)
        end
      end

      context('when multiple values provided') do
        let(:translator_genders) { %i[male female other] }
        let(:male_translator) { create(:authority, gender: 'male') }
        let(:female_translator) { create(:authority, gender: 'female') }
        let(:other_translator) { create(:authority, gender: 'other') }
        let(:unknown_translator) { create(:authority, gender: 'unknown') }
        let(:male) { create(:manifestation, translator: male_translator, orig_lang: 'en') }
        let(:female) { create(:manifestation, translator: female_translator, orig_lang: 'en') }
        let(:other) { create(:manifestation, translator: other_translator, orig_lang: 'en') }
        let(:unknown) { create(:manifestation, translator: unknown_translator, orig_lang: 'en') }

        before do
          Chewy.strategy(:atomic) do
            male
            female
            other
            unknown
          end
        end

        it 'returns all records where translator has any of given genders' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(male.id, female.id, other.id)
        end
      end
    end

    describe 'by title' do
      let(:filter) { { 'title' => title } }

      context 'when single word is provided' do
        let(:title) { 'lemon' }
        let(:lemon_tree) { create(:manifestation, title: 'A lemon tree') }
        let(:big_lemon) { create(:manifestation, title: 'The big lemon') }
        let(:orange_juice) { create(:manifestation, title: 'Orange juice') }

        before do
          Chewy.strategy(:atomic) do
            lemon_tree
            big_lemon
            orange_juice
          end
        end

        it 'returns all texts including given word in title' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(lemon_tree.id, big_lemon.id)
        end
      end

      context 'when multiple words are provided' do
        let(:title) { 'orange lemon' }
        let(:orange_lemon_tree) { create(:manifestation, title: 'The orange lemon tree') }
        let(:orange_lemon_cake) { create(:manifestation, title: 'Orange lemon cake') }
        let(:lemon_orange_cake) { create(:manifestation, title: 'Lemon orange cake') }

        before do
          Chewy.strategy(:atomic) do
            orange_lemon_tree
            orange_lemon_cake
            lemon_orange_cake
          end
        end

        it 'returns all texts having all this words in same order' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(orange_lemon_tree.id, orange_lemon_cake.id)
        end
      end

      context 'when multiple words are provided but in a wrong order' do
        # we're using phrase search for title. so order of words is important
        let(:title) { 'lemon orange' }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, title: 'The orange lemon tree')
            create(:manifestation, title: 'Orange lemon cake')
          end
        end

        it 'finds nothing' do
          expect(subject.count).to eq 0
        end
      end
    end

    describe 'by author' do
      let(:filter) { { 'author' => author } }

      context 'when author name is provided' do
        let(:author) { 'Alpha' }
        let(:alpha_author) { create(:authority, name: 'Alpha Smith') }
        let(:beta_author) { create(:authority, name: 'Beta Jones') }
        let(:alpha_1) { create(:manifestation, author: alpha_author) }
        let(:alpha_2) { create(:manifestation, author: alpha_author) }
        let(:beta) { create(:manifestation, author: beta_author) }

        before do
          Chewy.strategy(:atomic) do
            alpha_1
            alpha_2
            beta
          end
        end

        it 'returns all texts where author_string includes given name' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(alpha_1.id, alpha_2.id)
        end
      end

      context 'when translator name is provided' do
        let(:author) { 'Sigma' }
        let(:sigma_translator) { create(:authority, name: 'Sigma Brown') }
        let(:tau_translator) { create(:authority, name: 'Tau Green') }
        let(:sigma_1) { create(:manifestation, translator: sigma_translator, orig_lang: 'en') }
        let(:sigma_2) { create(:manifestation, translator: sigma_translator, orig_lang: 'en') }
        let(:tau) { create(:manifestation, translator: tau_translator, orig_lang: 'en') }

        before do
          Chewy.strategy(:atomic) do
            sigma_1
            sigma_2
            tau
          end
        end

        it 'returns all texts where author_string includes given name' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(sigma_1.id, sigma_2.id)
        end
      end

      context 'when multiple names are provided' do
        let(:author) { 'Alpha Sigma' }
        let(:alpha_author) { create(:authority, name: 'Alpha Smith') }
        let(:sigma_translator) { create(:authority, name: 'Sigma Brown') }
        let(:tau_translator) { create(:authority, name: 'Tau Green') }
        let(:alpha_sigma) do
          create(:manifestation, author: alpha_author, translator: sigma_translator, orig_lang: 'en')
        end
        let(:alpha_tau) { create(:manifestation, author: alpha_author, translator: tau_translator, orig_lang: 'en') }

        before do
          Chewy.strategy(:atomic) do
            alpha_sigma
            alpha_tau
          end
        end

        it 'returns all texts where author_string includes all of given names' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(alpha_sigma.id)
        end
      end
    end

    describe 'by fulltext' do
      let(:sort_by) { 'relevance' }
      let(:sort_dir) { 'desc' }
      let(:filter) { { 'fulltext' => fulltext } }
      let(:result_ids) { subject.map(&:id) }
      let(:manifestation_1) { create(:manifestation, markdown: 'The quick brown fox jumps over the lazy dog') }
      let(:manifestation_2) do
        create(:manifestation, markdown: 'Dogs are not our whole life, but they make our lives whole.')
      end
      # Adding word duplication to increase relevance by this word
      let(:manifestation_3) do
        create(:manifestation, markdown: 'Dogs do speak, but only to those who know how to listen. Dogs! Dogs! Dogs!')
      end

      before do
        Chewy.strategy(:atomic) do
          manifestation_1
          manifestation_2
          manifestation_3
        end
      end

      context 'when fulltext snippet is provided' do
        let(:fulltext) { 'lazy fox' }

        it 'returns records including those words' do
          expect(result_ids).to eq [manifestation_1.id]
        end
      end

      context 'when multiple documents match query' do
        let(:fulltext) { 'but dogs' }

        it 'orders them by relevance' do
          expect(result_ids).to eq [manifestation_3.id, manifestation_2.id]
        end
      end
    end

    describe 'by author_ids' do
      let(:filter) { { 'author_ids' => author_ids } }

      context 'when author id is provided' do
        let(:target_author) { create(:authority, name: 'Beta Smith') }
        let(:other_author) { create(:authority, name: 'Alpha Jones') }
        let(:author_ids) { [target_author.id] }
        let(:target_1) { create(:manifestation, author: target_author) }
        let(:target_2) { create(:manifestation, author: target_author) }
        let(:other) { create(:manifestation, author: other_author) }

        before do
          Chewy.strategy(:atomic) do
            target_1
            target_2
            other
          end
        end

        it 'returns all texts written by this author' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(target_1.id, target_2.id)
        end
      end

      context 'when translator id is provided' do
        let(:target_translator) { create(:authority, name: 'Rho Brown') }
        let(:other_translator) { create(:authority, name: 'Sigma Green') }
        let(:author_ids) { [target_translator.id] }
        let(:target_1) { create(:manifestation, translator: target_translator, orig_lang: 'en') }
        let(:target_2) { create(:manifestation, translator: target_translator, orig_lang: 'en') }
        let(:other) { create(:manifestation, translator: other_translator, orig_lang: 'en') }

        before do
          Chewy.strategy(:atomic) do
            target_1
            target_2
            other
          end
        end

        it 'returns all texts translated by this translator' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(target_1.id, target_2.id)
        end
      end
    end

    describe 'by original_languages' do
      let(:filter) { { 'original_languages' => orig_langs } }

      context 'when single language is provided' do
        let(:orig_langs) { ['ru'] }
        let(:russian_1) { create(:manifestation, orig_lang: 'ru') }
        let(:russian_2) { create(:manifestation, orig_lang: 'ru') }
        let(:english) { create(:manifestation, orig_lang: 'en') }
        let(:hebrew) { create(:manifestation, orig_lang: 'he') }

        before do
          Chewy.strategy(:atomic) do
            russian_1
            russian_2
            english
            hebrew
          end
        end

        it 'returns all texts written in given language' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(russian_1.id, russian_2.id)
        end
      end

      context 'when multiple languages are provided' do
        let(:orig_langs) { %w[ru he] }
        let(:russian) { create(:manifestation, orig_lang: 'ru') }
        let(:hebrew) { create(:manifestation, orig_lang: 'he') }
        let(:english) { create(:manifestation, orig_lang: 'en') }

        before do
          Chewy.strategy(:atomic) do
            russian
            hebrew
            english
          end
        end

        it 'returns all texts written in given languages' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(russian.id, hebrew.id)
        end
      end

      context 'when magic constant is provided' do
        let(:orig_langs) { ['xlat'] }
        let(:russian) { create(:manifestation, orig_lang: 'ru') }
        let(:english) { create(:manifestation, orig_lang: 'en') }
        let(:german) { create(:manifestation, orig_lang: 'de') }
        let(:hebrew) { create(:manifestation, orig_lang: 'he') }

        before do
          Chewy.strategy(:atomic) do
            russian
            english
            german
            hebrew
          end
        end

        it 'returns all translated texts' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(russian.id, english.id, german.id)
        end
      end

      context 'when magic constant with specific language is provided' do
        let(:orig_langs) { %w[xlat ru] }
        let(:russian) { create(:manifestation, orig_lang: 'ru') }
        let(:english) { create(:manifestation, orig_lang: 'en') }
        let(:hebrew) { create(:manifestation, orig_lang: 'he') }

        before do
          Chewy.strategy(:atomic) do
            russian
            english
            hebrew
          end
        end

        it 'returns all translated texts' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(russian.id, english.id)
        end
      end

      context 'when both magic constant and hebrew are provided' do
        let(:orig_langs) { %w[xlat he] }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, orig_lang: 'ru')
            create(:manifestation, orig_lang: 'en')
            create(:manifestation, orig_lang: 'he')
          end
        end

        it 'does no filterting and returns all texts' do
          expect(subject.count).to eq 3
        end
      end
    end

    describe 'by upload date' do
      let(:filter) { { 'uploaded_between' => range } }

      context "when 'from' and 'to' values are equal" do
        let(:range) { { 'from' => 2010, 'to' => 2010 } }
        let(:uploaded_2010_mid) { create(:manifestation, created_at: Time.parse('2010-06-15')) }
        let(:uploaded_2010_end) { create(:manifestation, created_at: Time.parse('2010-12-31')) }
        let(:uploaded_2009) { create(:manifestation, created_at: Time.parse('2009-12-31')) }
        let(:uploaded_2011) { create(:manifestation, created_at: Time.parse('2011-01-01')) }

        before do
          Chewy.strategy(:atomic) do
            uploaded_2010_mid
            uploaded_2010_end
            uploaded_2009
            uploaded_2011
          end
        end

        it 'returns all records uploaded in given year' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(uploaded_2010_mid.id, uploaded_2010_end.id)
        end
      end

      context "when 'from' and 'to' values are different" do
        let(:range) { { 'from' => 2010, 'to' => 2011 } }
        let(:uploaded_2010) { create(:manifestation, created_at: Time.parse('2010-01-01')) }
        let(:uploaded_2011) { create(:manifestation, created_at: Time.parse('2011-06-15')) }
        let(:uploaded_2009) { create(:manifestation, created_at: Time.parse('2009-12-31')) }
        let(:uploaded_2012) { create(:manifestation, created_at: Time.parse('2012-01-01')) }

        before do
          Chewy.strategy(:atomic) do
            uploaded_2010
            uploaded_2011
            uploaded_2009
            uploaded_2012
          end
        end

        it "returns all records uploaded from beginning of 'from' to end of 'to' year" do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(uploaded_2010.id, uploaded_2011.id)
        end
      end

      context "when only 'from' value provided" do
        let(:range) { { 'from' => 2012 } }
        let(:uploaded_2012) { create(:manifestation, created_at: Time.parse('2012-01-01')) }
        let(:uploaded_2013) { create(:manifestation, created_at: Time.parse('2013-06-15')) }
        let(:uploaded_2011) { create(:manifestation, created_at: Time.parse('2011-12-31')) }

        before do
          Chewy.strategy(:atomic) do
            uploaded_2012
            uploaded_2013
            uploaded_2011
          end
        end

        it 'returns all records uploaded starting from given year' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(uploaded_2012.id, uploaded_2013.id)
        end
      end

      context "when only 'to' value provided" do
        let(:range) { { 'to' => 2010 } }
        let(:uploaded_2010) { create(:manifestation, created_at: Time.parse('2010-06-15')) }
        let(:uploaded_2009) { create(:manifestation, created_at: Time.parse('2009-12-31')) }
        let(:uploaded_2011) { create(:manifestation, created_at: Time.parse('2011-01-01')) }

        before do
          Chewy.strategy(:atomic) do
            uploaded_2010
            uploaded_2009
            uploaded_2011
          end
        end

        it 'returns all records uploaded before given year' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(uploaded_2010.id, uploaded_2009.id)
        end
      end
    end

    describe 'by publication date' do
      let(:filter) { { 'published_between' => range } }

      context "when 'from' and 'to' values are equal" do
        let(:range) { { 'from' => 1980, 'to' => 1980 } }
        let(:published_1980_mid) { create(:manifestation, expression_date: '15.06.1980') }
        let(:published_1980_end) { create(:manifestation, expression_date: '31.12.1980') }
        let(:published_1979) { create(:manifestation, expression_date: '31.12.1979') }
        let(:published_1981) { create(:manifestation, expression_date: '01.01.1981') }

        before do
          Chewy.strategy(:atomic) do
            published_1980_mid
            published_1980_end
            published_1979
            published_1981
          end
        end

        it 'returns all records published in given year' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(published_1980_mid.id, published_1980_end.id)
        end
      end

      context "when 'from' and 'to' values are different" do
        let(:range) { { 'from' => 1990, 'to' => 1992 } }
        let(:published_1990) { create(:manifestation, expression_date: '01.01.1990') }
        let(:published_1991) { create(:manifestation, expression_date: '15.06.1991') }
        let(:published_1992) { create(:manifestation, expression_date: '31.12.1992') }
        let(:published_1989) { create(:manifestation, expression_date: '31.12.1989') }
        let(:published_1993) { create(:manifestation, expression_date: '01.01.1993') }

        before do
          Chewy.strategy(:atomic) do
            published_1990
            published_1991
            published_1992
            published_1989
            published_1993
          end
        end

        it "returns all records published from beginning of 'from' to end of 'to' year" do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(published_1990.id, published_1991.id, published_1992.id)
        end
      end

      context "when only 'from' value provided" do
        let(:range) { { 'from' => 1985 } }
        let(:published_1985) { create(:manifestation, expression_date: '01.01.1985') }
        let(:published_1990) { create(:manifestation, expression_date: '15.06.1990') }
        let(:published_1984) { create(:manifestation, expression_date: '31.12.1984') }

        before do
          Chewy.strategy(:atomic) do
            published_1985
            published_1990
            published_1984
          end
        end

        it 'returns all records published starting from given year' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(published_1985.id, published_1990.id)
        end
      end

      context "when only 'to' value provided" do
        let(:range) { { 'to' => 1984 } }
        let(:published_1984) { create(:manifestation, expression_date: '15.06.1984') }
        let(:published_1983) { create(:manifestation, expression_date: '31.12.1983') }
        let(:published_1985) { create(:manifestation, expression_date: '01.01.1985') }

        before do
          Chewy.strategy(:atomic) do
            published_1984
            published_1983
            published_1985
          end
        end

        it 'returns all records published before or in given year' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(published_1984.id, published_1983.id)
        end
      end
    end

    describe 'by creation date' do
      let(:filter) { { 'created_between' => range } }

      context "when 'from' and 'to' values are equal" do
        let(:range) { { 'from' => 1950, 'to' => 1950 } }
        let(:created_1950_mid) { create(:manifestation, work_date: '15.06.1950') }
        let(:created_1950_end) { create(:manifestation, work_date: '31.12.1950') }
        let(:created_1949) { create(:manifestation, work_date: '31.12.1949') }
        let(:created_1951) { create(:manifestation, work_date: '01.01.1951') }

        before do
          Chewy.strategy(:atomic) do
            created_1950_mid
            created_1950_end
            created_1949
            created_1951
          end
        end

        it 'returns all records created in given year' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(created_1950_mid.id, created_1950_end.id)
        end
      end

      context "when 'from' and 'to' values are different" do
        let(:range) { { 'from' => 1950, 'to' => 1952 } }
        let(:created_1950) { create(:manifestation, work_date: '01.01.1950') }
        let(:created_1951) { create(:manifestation, work_date: '15.06.1951') }
        let(:created_1952) { create(:manifestation, work_date: '31.12.1952') }
        let(:created_1949) { create(:manifestation, work_date: '31.12.1949') }
        let(:created_1953) { create(:manifestation, work_date: '01.01.1953') }

        before do
          Chewy.strategy(:atomic) do
            created_1950
            created_1951
            created_1952
            created_1949
            created_1953
          end
        end

        it "returns all records created from beginning of 'from' to end of 'to' year" do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(created_1950.id, created_1951.id, created_1952.id)
        end
      end

      context "when only 'from' value provided" do
        let(:range) { { 'from' => 1985 } }
        let(:created_1985) { create(:manifestation, work_date: '01.01.1985') }
        let(:created_1990) { create(:manifestation, work_date: '15.06.1990') }
        let(:created_1984) { create(:manifestation, work_date: '31.12.1984') }

        before do
          Chewy.strategy(:atomic) do
            created_1985
            created_1990
            created_1984
          end
        end

        it 'returns all records created starting from given year' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(created_1985.id, created_1990.id)
        end
      end

      context "when only 'to' value provided" do
        let(:range) { { 'to' => 1952 } }
        let(:created_1952) { create(:manifestation, work_date: '15.06.1952') }
        let(:created_1951) { create(:manifestation, work_date: '31.12.1951') }
        let(:created_1953) { create(:manifestation, work_date: '01.01.1953') }

        before do
          Chewy.strategy(:atomic) do
            created_1952
            created_1951
            created_1953
          end
        end

        it 'returns all records created before or in given year' do
          result_ids = subject.map(&:id)
          expect(result_ids).to contain_exactly(created_1952.id, created_1951.id)
        end
      end
    end
  end

  describe 'sorting' do
    describe 'alphabetical' do
      let(:sorting) { 'alphabetical' }
      let(:manifestation_a) { create(:manifestation, title: 'Apple') }
      let(:manifestation_b) { create(:manifestation, title: 'Banana') }
      let(:manifestation_c) { create(:manifestation, title: 'Cherry') }

      before do
        Chewy.strategy(:atomic) do
          manifestation_a
          manifestation_b
          manifestation_c
        end
      end

      context 'when default sort direction is requested' do
        let(:sort_dir) { 'default' }

        it 'sorts in ascending order' do
          result_ids = described_class.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [manifestation_a.id, manifestation_b.id, manifestation_c.id]
        end
      end

      context 'when asc sort direction is requested' do
        let(:sort_dir) { 'asc' }

        it 'sorts in ascending order' do
          result_ids = described_class.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [manifestation_a.id, manifestation_b.id, manifestation_c.id]
        end
      end

      context 'when desc sort direction is requested' do
        let(:sort_dir) { 'desc' }

        it 'sorts in descending order' do
          result_ids = described_class.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [manifestation_c.id, manifestation_b.id, manifestation_a.id]
        end
      end
    end

    describe 'popularity' do
      let(:sorting) { 'popularity' }
      let(:manifestation_low) { create(:manifestation, impressions_count: 10) }
      let(:manifestation_mid) { create(:manifestation, impressions_count: 50) }
      let(:manifestation_high) { create(:manifestation, impressions_count: 100) }

      before do
        Chewy.strategy(:atomic) do
          manifestation_low
          manifestation_mid
          manifestation_high
        end
      end

      context 'when default sort direction is requested' do
        let(:sort_dir) { 'default' }

        it 'sorts in descending order by default' do
          result_ids = described_class.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [manifestation_high.id, manifestation_mid.id, manifestation_low.id]
        end
      end

      context 'when asc sort direction is requested' do
        let(:sort_dir) { 'asc' }

        it 'sorts in ascending order' do
          result_ids = described_class.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [manifestation_low.id, manifestation_mid.id, manifestation_high.id]
        end
      end

      context 'when desc sort direction is requested' do
        let(:sort_dir) { 'desc' }

        it 'sorts in descending order' do
          result_ids = described_class.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [manifestation_high.id, manifestation_mid.id, manifestation_low.id]
        end
      end
    end

    describe 'publication_date' do
      let(:sorting) { 'publication_date' }
      let(:manifestation_early) { create(:manifestation, expression_date: '01.01.1980') }
      let(:manifestation_mid) { create(:manifestation, expression_date: '01.01.1990') }
      let(:manifestation_late) { create(:manifestation, expression_date: '01.01.2000') }

      before do
        Chewy.strategy(:atomic) do
          manifestation_early
          manifestation_mid
          manifestation_late
        end
      end

      context 'when default sort direction is requested' do
        let(:sort_dir) { 'default' }

        it 'sorts in ascending order by default' do
          result_ids = described_class.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [manifestation_early.id, manifestation_mid.id, manifestation_late.id]
        end
      end

      context 'when asc sort direction is requested' do
        let(:sort_dir) { 'asc' }

        it 'sorts in ascending order' do
          result_ids = described_class.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [manifestation_early.id, manifestation_mid.id, manifestation_late.id]
        end
      end

      context 'when desc sort direction is requested' do
        let(:sort_dir) { 'desc' }

        it 'sorts in descending order' do
          result_ids = described_class.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [manifestation_late.id, manifestation_mid.id, manifestation_early.id]
        end
      end
    end

    describe 'creation_date' do
      let(:sorting) { 'creation_date' }
      let(:manifestation_early) { create(:manifestation, work_date: '01.01.1950') }
      let(:manifestation_mid) { create(:manifestation, work_date: '01.01.1970') }
      let(:manifestation_late) { create(:manifestation, work_date: '01.01.1990') }

      before do
        Chewy.strategy(:atomic) do
          manifestation_early
          manifestation_mid
          manifestation_late
        end
      end

      context 'when default sort direction is requested' do
        let(:sort_dir) { 'default' }

        it 'sorts in ascending order by default' do
          result_ids = described_class.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [manifestation_early.id, manifestation_mid.id, manifestation_late.id]
        end
      end

      context 'when asc sort direction is requested' do
        let(:sort_dir) { 'asc' }

        it 'sorts in ascending order' do
          result_ids = described_class.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [manifestation_early.id, manifestation_mid.id, manifestation_late.id]
        end
      end

      context 'when desc sort direction is requested' do
        let(:sort_dir) { 'desc' }

        it 'sorts in descending order' do
          result_ids = described_class.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [manifestation_late.id, manifestation_mid.id, manifestation_early.id]
        end
      end
    end

    describe 'upload_date' do
      let(:sorting) { 'upload_date' }
      let(:manifestation_early) { create(:manifestation, created_at: Time.parse('2010-01-01')) }
      let(:manifestation_mid) { create(:manifestation, created_at: Time.parse('2015-01-01')) }
      let(:manifestation_late) { create(:manifestation, created_at: Time.parse('2020-01-01')) }

      before do
        Chewy.strategy(:atomic) do
          manifestation_early
          manifestation_mid
          manifestation_late
        end
      end

      context 'when default sort direction is requested' do
        let(:sort_dir) { 'default' }

        it 'sorts in descending order by default' do
          result_ids = described_class.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [manifestation_late.id, manifestation_mid.id, manifestation_early.id]
        end
      end

      context 'when asc sort direction is requested' do
        let(:sort_dir) { 'asc' }

        it 'sorts in ascending order' do
          result_ids = described_class.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [manifestation_early.id, manifestation_mid.id, manifestation_late.id]
        end
      end

      context 'when desc sort direction is requested' do
        let(:sort_dir) { 'desc' }

        it 'sorts in descending order' do
          result_ids = described_class.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [manifestation_late.id, manifestation_mid.id, manifestation_early.id]
        end
      end
    end
  end
end
