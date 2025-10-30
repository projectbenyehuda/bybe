require 'rails_helper'

describe SearchManifestations do
  before(:each) do
    clean_tables
  end

  describe 'filtering' do
    subject!(:result) { described_class.call(sort_by, sort_dir, filter) }

    let(:sort_by) { 'alphabetical' }
    let(:sort_dir) { 'asc' }

    describe 'by genres' do
      let(:filter) { { 'genres' => genres } }

      context 'when single genre specified' do
        let(:genres) { %w(poetry) }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, genre: 'poetry', title: 'Poem 1')
            create(:manifestation, genre: 'poetry', title: 'Poem 2')
            create(:manifestation, genre: 'prose', title: 'Prose 1')
            create(:manifestation, genre: 'drama', title: 'Drama 1')
          end
        end

        it 'returns all texts where genre is equal to provided value' do
          expect(subject.count).to eq 2
          subject.each do |rec|
            expect(rec.genre).to eq 'poetry'
          end
        end
      end

      context 'when multiple genres specified' do
        let(:genres) { %w(poetry article) }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, genre: 'poetry', title: 'Poem 1')
            create(:manifestation, genre: 'article', title: 'Article 1')
            create(:manifestation, genre: 'prose', title: 'Prose 1')
          end
        end

        it 'returns all texts where genre is included in provided list' do
          expect(subject.count).to eq 2
          subject.each do |rec|
            expect(%w(poetry article)).to include rec.genre
          end
        end
      end
    end

    describe 'by periods' do
      let(:filter) { { 'periods' => periods } }

      context 'when single period specified' do
        let(:periods) { %w(ancient) }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, period: 'ancient', title: 'Ancient 1')
            create(:manifestation, period: 'ancient', title: 'Ancient 2')
            create(:manifestation, period: 'modern', title: 'Modern 1')
            create(:manifestation, period: 'medieval', title: 'Medieval 1')
          end
        end

        it 'returns all texts where period is equal to provided value' do
          expect(subject.count).to eq 2
          subject.each do |rec|
            expect(rec.period).to eq 'ancient'
          end
        end
      end

      context 'when multiple periods specified' do
        let(:periods) { %w(ancient revival) }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, period: 'ancient', title: 'Ancient 1')
            create(:manifestation, period: 'revival', title: 'Revival 1')
            create(:manifestation, period: 'modern', title: 'Modern 1')
          end
        end

        it 'returns all texts where period is included in provided list' do
          expect(subject.count).to eq 2
          subject.each do |rec|
            expect(%w(ancient revival)).to include rec.period
          end
        end
      end
    end

    describe 'by intellectual property types' do
      let(:types) { %w(public_domain unknown) }
      let(:filter)  { { 'intellectual_property_types' => types } }

      before do
        Chewy.strategy(:atomic) do
          create(:manifestation, intellectual_property: 'public_domain', title: 'Public 1')
          create(:manifestation, intellectual_property: 'unknown', title: 'Unknown 1')
          create(:manifestation, intellectual_property: 'copyrighted', title: 'Copyrighted 1')
        end
      end

      it 'returns all works with given intellectual property types' do
        expect(result.count).to eq 2
        result.each do |rec|
          expect(types).to include(rec.intellectual_property)
        end
      end
    end

    describe 'by author_genders' do
      let(:filter) { { 'author_genders' => author_genders } }

      context('when single value provided') do
        let(:author_genders) { [:male] }

        before do
          Chewy.strategy(:atomic) do
            male_author = create(:authority, gender: 'male')
            female_author = create(:authority, gender: 'female')
            create(:manifestation, author: male_author, title: 'Male Author 1')
            create(:manifestation, author: male_author, title: 'Male Author 2')
            create(:manifestation, author: female_author, title: 'Female Author 1')
          end
        end

        it 'returns all records where author has given gender' do
          expect(subject.count).to eq 2
          subject.each do |rec|
            expect(rec.author_gender).to eq %w(male)
          end
        end
      end

      context('when multiple values provided') do
        let(:author_genders) { [:male, :female, :unknown] }

        before do
          Chewy.strategy(:atomic) do
            male_author = create(:authority, gender: 'male')
            female_author = create(:authority, gender: 'female')
            unknown_author = create(:authority, gender: 'unknown')
            other_author = create(:authority, gender: 'other')
            create(:manifestation, author: male_author, title: 'Male Author 1')
            create(:manifestation, author: female_author, title: 'Female Author 1')
            create(:manifestation, author: unknown_author, title: 'Unknown Author 1')
            create(:manifestation, author: other_author, title: 'Other Author 1')
          end
        end

        it 'returns all records where author has any of given genders' do
          expect(subject.count).to eq 3
          subject.each do |rec|
            expect([%w(male), %w(female), %w(unknown)]).to include rec.author_gender
          end
        end
      end
    end

    describe 'by translator_genders' do
      let(:filter) { { 'translator_genders' => translator_genders } }

      context('when single value provided') do
        let(:translator_genders) { [:female] }

        before do
          Chewy.strategy(:atomic) do
            female_translator = create(:authority, gender: 'female')
            male_translator = create(:authority, gender: 'male')
            create(:manifestation, translator: female_translator, orig_lang: 'en', title: 'Female Trans 1')
            create(:manifestation, translator: female_translator, orig_lang: 'en', title: 'Female Trans 2')
            create(:manifestation, translator: male_translator, orig_lang: 'en', title: 'Male Trans 1')
          end
        end

        it 'returns all records where translator has given gender' do
          expect(subject.count).to eq 2
          subject.each do |rec|
            expect(rec.translator_gender).to eq %w(female)
          end
        end
      end

      context('when multiple values provided') do
        let(:translator_genders) { [:male, :female, :other] }

        before do
          Chewy.strategy(:atomic) do
            male_translator = create(:authority, gender: 'male')
            female_translator = create(:authority, gender: 'female')
            other_translator = create(:authority, gender: 'other')
            unknown_translator = create(:authority, gender: 'unknown')
            create(:manifestation, translator: male_translator, orig_lang: 'en', title: 'Male Trans 1')
            create(:manifestation, translator: female_translator, orig_lang: 'en', title: 'Female Trans 1')
            create(:manifestation, translator: other_translator, orig_lang: 'en', title: 'Other Trans 1')
            create(:manifestation, translator: unknown_translator, orig_lang: 'en', title: 'Unknown Trans 1')
          end
        end

        it 'returns all records where translator has any of given genders' do
          expect(subject.count).to eq 3
          subject.each do |rec|
            expect([%w(male), %w(female), %w(other)]).to include rec.translator_gender
          end
        end
      end
    end

    describe 'by title' do
      let(:filter) { { 'title' => title } }

      context 'when single word is provided' do
        let(:title) { 'lemon' }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, title: 'A lemon tree')
            create(:manifestation, title: 'The big lemon')
            create(:manifestation, title: 'Orange juice')
          end
        end

        it 'returns all texts including given word in title' do
          expect(subject.count).to eq 2
          subject.each do |rec|
            expect(rec.title).to match /lemon/
          end
        end
      end

      context 'when multiple words are provided' do
        let(:title) { 'orange lemon' }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, title: 'The orange lemon tree')
            create(:manifestation, title: 'Orange lemon cake')
            create(:manifestation, title: 'Lemon orange cake')
          end
        end

        it 'returns all texts having all this words in same order' do
          expect(subject.count).to eq 2
          subject.each do |rec|
            expect(rec.title).to match /orange lemon/i
          end
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

        before do
          Chewy.strategy(:atomic) do
            alpha_author = create(:authority, name: 'Alpha Smith')
            beta_author = create(:authority, name: 'Beta Jones')
            create(:manifestation, author: alpha_author, title: 'Alpha Book 1')
            create(:manifestation, author: alpha_author, title: 'Alpha Book 2')
            create(:manifestation, author: beta_author, title: 'Beta Book 1')
          end
        end

        it 'returns all texts where author_string includes given name' do
          expect(subject.count).to eq 2
          subject.each do |rec|
            expect(rec.author_string).to match /Alpha/
          end
        end
      end

      context 'when translator name is provided' do
        let(:author) { 'Sigma' }

        before do
          Chewy.strategy(:atomic) do
            sigma_translator = create(:authority, name: 'Sigma Brown')
            tau_translator = create(:authority, name: 'Tau Green')
            create(:manifestation, translator: sigma_translator, orig_lang: 'en', title: 'Sigma Trans 1')
            create(:manifestation, translator: sigma_translator, orig_lang: 'en', title: 'Sigma Trans 2')
            create(:manifestation, translator: tau_translator, orig_lang: 'en', title: 'Tau Trans 1')
          end
        end

        it 'returns all texts where author_string includes given name' do
          expect(subject.count).to eq 2
          subject.each do |rec|
            expect(rec.author_string).to match /Sigma/
          end
        end
      end

      context 'when multiple names are provided' do
        let(:author) { 'Alpha Sigma' }

        before do
          Chewy.strategy(:atomic) do
            alpha_author = create(:authority, name: 'Alpha Smith')
            sigma_translator = create(:authority, name: 'Sigma Brown')
            tau_translator = create(:authority, name: 'Tau Green')
            create(:manifestation, author: alpha_author, translator: sigma_translator, orig_lang: 'en', title: 'Alpha Sigma 1')
            create(:manifestation, author: alpha_author, translator: tau_translator, orig_lang: 'en', title: 'Alpha Tau 1')
          end
        end

        it 'returns all texts where author_string includes all of given names' do
          expect(subject.count).to eq 1
          # it takes in account both authors and translators names
          subject.each do |rec|
            expect(rec.author_string).to match /Alpha/
            expect(rec.author_string).to match /Sigma/
          end
        end
      end
    end

    describe 'by fulltext' do
      let(:sort_by) { 'relevance' }
      let(:sort_dir) { 'desc' }
      let(:filter) { { 'fulltext' => fulltext } }
      let(:result_ids) { subject.map(&:id) }
      let(:manifestation_1) { create(:manifestation, markdown: 'The quick brown fox jumps over the lazy dog') }
      let(:manifestation_2) { create(:manifestation, markdown: 'Dogs are not our whole life, but they make our lives whole.') }
      # Adding word duplication to increase relevance by this word
      let(:manifestation_3) { create(:manifestation, markdown: 'Dogs do speak, but only to those who know how to listen. Dogs! Dogs! Dogs!') }

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
          expect(result_ids).to eq [ manifestation_1.id ]
        end
      end

      context 'when multiple documents match query' do
        let(:fulltext) { 'but dogs' }
        it 'orders them by relevance' do
          expect(result_ids).to eq [ manifestation_3.id, manifestation_2.id ]
        end
      end
    end

    describe 'by author_ids' do
      let(:filter) { { 'author_ids' => author_ids } }

      context 'when author id is provided' do
        let!(:target_author) { create(:authority, name: 'Beta Smith') }
        let!(:other_author) { create(:authority, name: 'Alpha Jones') }
        let(:author_ids) { [ target_author.id ] }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, author: target_author, title: 'Beta Book 1')
            create(:manifestation, author: target_author, title: 'Beta Book 2')
            create(:manifestation, author: other_author, title: 'Alpha Book 1')
          end
        end

        it 'returns all texts written by this author' do
          expect(subject.count).to eq 2
          subject.each do |rec|
            expect(rec.author_ids).to include target_author.id
          end
        end
      end

      context 'when translator id is provided' do
        let!(:target_translator) { create(:authority, name: 'Rho Brown') }
        let!(:other_translator) { create(:authority, name: 'Sigma Green') }
        let(:author_ids) { [ target_translator.id ] }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, translator: target_translator, orig_lang: 'en', title: 'Rho Trans 1')
            create(:manifestation, translator: target_translator, orig_lang: 'en', title: 'Rho Trans 2')
            create(:manifestation, translator: other_translator, orig_lang: 'en', title: 'Sigma Trans 1')
          end
        end

        it 'returns all texts translated by this translator' do
          expect(subject.count).to eq 2
          subject.each do |rec|
            expect(rec.author_ids).to include target_translator.id
          end
        end
      end
    end

    describe 'by original_languages' do
      let(:filter) { { 'original_languages' => orig_langs } }

      context 'when single language is provided' do
        let(:orig_langs) { ['ru'] }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, orig_lang: 'ru', title: 'Russian 1')
            create(:manifestation, orig_lang: 'ru', title: 'Russian 2')
            create(:manifestation, orig_lang: 'en', title: 'English 1')
            create(:manifestation, orig_lang: 'he', title: 'Hebrew 1')
          end
        end

        it 'returns all texts written in given language' do
          expect(subject.count).to eq 2
          subject.each do |rec|
            expect(rec.orig_lang).to eq 'ru'
          end
        end
      end

      context 'when multiple languages are provided' do
        let(:orig_langs) { %w(ru he) }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, orig_lang: 'ru', title: 'Russian 1')
            create(:manifestation, orig_lang: 'he', title: 'Hebrew 1')
            create(:manifestation, orig_lang: 'en', title: 'English 1')
          end
        end

        it 'returns all texts written in given languages' do
          expect(subject.count).to eq 2
          subject.each do |rec|
            expect(%w(ru he).include?(rec.orig_lang)).to be_truthy
          end
        end
      end

      context 'when magic constant is provided' do
        let(:orig_langs) { ['xlat'] }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, orig_lang: 'ru', title: 'Russian 1')
            create(:manifestation, orig_lang: 'en', title: 'English 1')
            create(:manifestation, orig_lang: 'de', title: 'German 1')
            create(:manifestation, orig_lang: 'he', title: 'Hebrew 1')
          end
        end

        it 'returns all translated texts' do
          expect(subject.count).to eq 3
          subject.each do |rec|
            expect(rec.orig_lang).to_not eq 'he'
          end
        end
      end

      context 'when magic constant with specific language is provided' do
        let(:orig_langs) { %w(xlat ru) }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, orig_lang: 'ru', title: 'Russian 1')
            create(:manifestation, orig_lang: 'en', title: 'English 1')
            create(:manifestation, orig_lang: 'he', title: 'Hebrew 1')
          end
        end

        it 'returns all translated texts' do
          expect(subject.count).to eq 2
          subject.each do |rec|
            expect(rec.orig_lang).to_not eq 'he'
          end
        end
      end

      context 'when both magic constant and hebrew are provided' do
        let(:orig_langs) { %w(xlat he) }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, orig_lang: 'ru', title: 'Russian 1')
            create(:manifestation, orig_lang: 'en', title: 'English 1')
            create(:manifestation, orig_lang: 'he', title: 'Hebrew 1')
          end
        end

        it 'does no filterting and returns all texts' do
          expect(subject.count).to eq 3
        end
      end
    end

    describe 'by upload date' do
      let(:filter) { { 'uploaded_between' => range } }
      let(:index_attr) { :pby_publication_date }

      context "when 'from' and 'to' values are equal" do
        let(:range) { { 'from' => 2010, 'to' => 2010 } }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, created_at: Time.parse('2010-06-15'), title: 'Uploaded 2010-1')
            create(:manifestation, created_at: Time.parse('2010-12-31'), title: 'Uploaded 2010-2')
            create(:manifestation, created_at: Time.parse('2009-12-31'), title: 'Uploaded 2009')
            create(:manifestation, created_at: Time.parse('2011-01-01'), title: 'Uploaded 2011')
          end
        end

        it 'returns all records uploaded in given year' do
          assert_date_range(2)
        end
      end

      context "when 'from' and 'to' values are different" do
        let(:range) { { 'from' => 2010, 'to' => 2011 } }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, created_at: Time.parse('2010-01-01'), title: 'Uploaded 2010')
            create(:manifestation, created_at: Time.parse('2011-06-15'), title: 'Uploaded 2011')
            create(:manifestation, created_at: Time.parse('2009-12-31'), title: 'Uploaded 2009')
            create(:manifestation, created_at: Time.parse('2012-01-01'), title: 'Uploaded 2012')
          end
        end

        it "returns all records uploaded from beginning of 'from' to end of 'to' year" do
          assert_date_range(2)
        end
      end

      context "when only 'from' value provided" do
        let(:range) { { 'from' => 2012 } }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, created_at: Time.parse('2012-01-01'), title: 'Uploaded 2012')
            create(:manifestation, created_at: Time.parse('2013-06-15'), title: 'Uploaded 2013')
            create(:manifestation, created_at: Time.parse('2011-12-31'), title: 'Uploaded 2011')
          end
        end

        it 'returns all records uploaded starting from given year' do
          assert_date_range(2)
        end
      end

      context "when only 'to' value provided" do
        let(:range) { { 'to' => 2010 } }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, created_at: Time.parse('2010-06-15'), title: 'Uploaded 2010')
            create(:manifestation, created_at: Time.parse('2009-12-31'), title: 'Uploaded 2009')
            create(:manifestation, created_at: Time.parse('2011-01-01'), title: 'Uploaded 2011')
          end
        end

        it 'returns all records uploaded before given year' do
          assert_date_range(2)
        end
      end
    end

    describe 'by publication date' do
      let(:filter) { { 'published_between' => range } }
      let(:index_attr) { :orig_publication_date }

      context "when 'from' and 'to' values are equal" do
        let(:range) { { 'from' => 1980, 'to' => 1980 } }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, expression_date: '15.06.1980', title: 'Published 1980-1')
            create(:manifestation, expression_date: '31.12.1980', title: 'Published 1980-2')
            create(:manifestation, expression_date: '31.12.1979', title: 'Published 1979')
            create(:manifestation, expression_date: '01.01.1981', title: 'Published 1981')
          end
        end

        it 'returns all records published in given year' do
          assert_date_range(2)
        end
      end

      context "when 'from' and 'to' values are different" do
        let(:range) { { 'from' => 1990, 'to' => 1992 } }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, expression_date: '01.01.1990', title: 'Published 1990')
            create(:manifestation, expression_date: '15.06.1991', title: 'Published 1991')
            create(:manifestation, expression_date: '31.12.1992', title: 'Published 1992')
            create(:manifestation, expression_date: '31.12.1989', title: 'Published 1989')
            create(:manifestation, expression_date: '01.01.1993', title: 'Published 1993')
          end
        end

        it "returns all records published from beginning of 'from' to end of 'to' year" do
          assert_date_range(3)
        end
      end

      context "when only 'from' value provided" do
        let(:range) { { 'from' => 1985 } }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, expression_date: '01.01.1985', title: 'Published 1985')
            create(:manifestation, expression_date: '15.06.1990', title: 'Published 1990')
            create(:manifestation, expression_date: '31.12.1984', title: 'Published 1984')
          end
        end

        it 'returns all records published starting from given year' do
          assert_date_range(2)
        end
      end

      context "when only 'to' value provided" do
        let(:range) { { 'to' => 1984 } }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, expression_date: '15.06.1984', title: 'Published 1984')
            create(:manifestation, expression_date: '31.12.1983', title: 'Published 1983')
            create(:manifestation, expression_date: '01.01.1985', title: 'Published 1985')
          end
        end

        it 'returns all records published before or in given year' do
          assert_date_range(2)
        end
      end
    end

    describe 'by creation date' do
      let(:filter) { { 'created_between' => range } }
      let(:index_attr) { :creation_date }

      context "when 'from' and 'to' values are equal" do
        let(:range) { { 'from' => 1950, 'to' => 1950 } }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, work_date: '15.06.1950', title: 'Created 1950-1')
            create(:manifestation, work_date: '31.12.1950', title: 'Created 1950-2')
            create(:manifestation, work_date: '31.12.1949', title: 'Created 1949')
            create(:manifestation, work_date: '01.01.1951', title: 'Created 1951')
          end
        end

        it 'returns all records created in given year' do
          assert_date_range(2)
        end
      end

      context "when 'from' and 'to' values are different" do
        let(:range) { { 'from' => 1950, 'to' => 1952 } }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, work_date: '01.01.1950', title: 'Created 1950')
            create(:manifestation, work_date: '15.06.1951', title: 'Created 1951')
            create(:manifestation, work_date: '31.12.1952', title: 'Created 1952')
            create(:manifestation, work_date: '31.12.1949', title: 'Created 1949')
            create(:manifestation, work_date: '01.01.1953', title: 'Created 1953')
          end
        end

        it "returns all records created from beginning of 'from' to end of 'to' year" do
          assert_date_range(3)
        end
      end

      context "when only 'from' value provided" do
        let(:range) { { 'from' => 1985 } }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, work_date: '01.01.1985', title: 'Created 1985')
            create(:manifestation, work_date: '15.06.1990', title: 'Created 1990')
            create(:manifestation, work_date: '31.12.1984', title: 'Created 1984')
          end
        end

        it 'returns all records created starting from given year' do
          assert_date_range(2)
        end
      end

      context "when only 'to' value provided" do
        let(:range) { { 'to' => 1952 } }

        before do
          Chewy.strategy(:atomic) do
            create(:manifestation, work_date: '15.06.1952', title: 'Created 1952')
            create(:manifestation, work_date: '31.12.1951', title: 'Created 1951')
            create(:manifestation, work_date: '01.01.1953', title: 'Created 1953')
          end
        end

        it 'returns all records created before or in given year' do
          assert_date_range(2)
        end
      end
    end
  end

  describe 'sorting' do
    describe 'alphabetical' do
      let(:sorting) { 'alphabetical' }
      let!(:manifestation_a) { nil }
      let!(:manifestation_b) { nil }
      let!(:manifestation_c) { nil }

      before do
        Chewy.strategy(:atomic) do
          @manifestation_a = create(:manifestation, title: 'Apple')
          @manifestation_b = create(:manifestation, title: 'Banana')
          @manifestation_c = create(:manifestation, title: 'Cherry')
        end
      end

      context 'when default sort direction is requested' do
        let(:sort_dir) { 'default'}
        it 'sorts in ascending order' do
          result_ids = SearchManifestations.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [@manifestation_a.id, @manifestation_b.id, @manifestation_c.id]
        end
      end

      context 'when asc sort direction is requested' do
        let(:sort_dir) { 'asc'}
        it 'sorts in ascending order' do
          result_ids = SearchManifestations.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [@manifestation_a.id, @manifestation_b.id, @manifestation_c.id]
        end
      end

      context 'when desc sort direction is requested' do
        let(:sort_dir) { 'desc'}
        it 'sorts in descending order' do
          result_ids = SearchManifestations.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [@manifestation_c.id, @manifestation_b.id, @manifestation_a.id]
        end
      end
    end

    describe 'popularity' do
      let(:sorting) { 'popularity' }

      before do
        Chewy.strategy(:atomic) do
          @manifestation_low = create(:manifestation, impressions_count: 10, title: 'Low')
          @manifestation_mid = create(:manifestation, impressions_count: 50, title: 'Mid')
          @manifestation_high = create(:manifestation, impressions_count: 100, title: 'High')
        end
      end

      context 'when default sort direction is requested' do
        let(:sort_dir) { 'default'}
        it 'sorts in descending order by default' do
          result_ids = SearchManifestations.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [@manifestation_high.id, @manifestation_mid.id, @manifestation_low.id]
        end
      end

      context 'when asc sort direction is requested' do
        let(:sort_dir) { 'asc'}
        it 'sorts in ascending order' do
          result_ids = SearchManifestations.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [@manifestation_low.id, @manifestation_mid.id, @manifestation_high.id]
        end
      end

      context 'when desc sort direction is requested' do
        let(:sort_dir) { 'desc'}
        it 'sorts in descending order' do
          result_ids = SearchManifestations.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [@manifestation_high.id, @manifestation_mid.id, @manifestation_low.id]
        end
      end
    end

    describe 'publication_date' do
      let(:sorting) { 'publication_date' }

      before do
        Chewy.strategy(:atomic) do
          @manifestation_early = create(:manifestation, expression_date: '01.01.1980', title: 'Early')
          @manifestation_mid = create(:manifestation, expression_date: '01.01.1990', title: 'Mid')
          @manifestation_late = create(:manifestation, expression_date: '01.01.2000', title: 'Late')
        end
      end

      context 'when default sort direction is requested' do
        let(:sort_dir) { 'default'}
        it 'sorts in ascending order by default' do
          result_ids = SearchManifestations.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [@manifestation_early.id, @manifestation_mid.id, @manifestation_late.id]
        end
      end

      context 'when asc sort direction is requested' do
        let(:sort_dir) { 'asc'}
        it 'sorts in ascending order' do
          result_ids = SearchManifestations.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [@manifestation_early.id, @manifestation_mid.id, @manifestation_late.id]
        end
      end

      context 'when desc sort direction is requested' do
        let(:sort_dir) { 'desc'}
        it 'sorts in descending order' do
          result_ids = SearchManifestations.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [@manifestation_late.id, @manifestation_mid.id, @manifestation_early.id]
        end
      end
    end

    describe 'creation_date' do
      let(:sorting) { 'creation_date' }

      before do
        Chewy.strategy(:atomic) do
          @manifestation_early = create(:manifestation, work_date: '01.01.1950', title: 'Early')
          @manifestation_mid = create(:manifestation, work_date: '01.01.1970', title: 'Mid')
          @manifestation_late = create(:manifestation, work_date: '01.01.1990', title: 'Late')
        end
      end

      context 'when default sort direction is requested' do
        let(:sort_dir) { 'default'}
        it 'sorts in ascending order by default' do
          result_ids = SearchManifestations.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [@manifestation_early.id, @manifestation_mid.id, @manifestation_late.id]
        end
      end

      context 'when asc sort direction is requested' do
        let(:sort_dir) { 'asc'}
        it 'sorts in ascending order' do
          result_ids = SearchManifestations.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [@manifestation_early.id, @manifestation_mid.id, @manifestation_late.id]
        end
      end

      context 'when desc sort direction is requested' do
        let(:sort_dir) { 'desc'}
        it 'sorts in descending order' do
          result_ids = SearchManifestations.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [@manifestation_late.id, @manifestation_mid.id, @manifestation_early.id]
        end
      end
    end

    describe 'upload_date' do
      let(:sorting) { 'upload_date' }

      before do
        Chewy.strategy(:atomic) do
          @manifestation_early = create(:manifestation, created_at: Time.parse('2010-01-01'), title: 'Early')
          @manifestation_mid = create(:manifestation, created_at: Time.parse('2015-01-01'), title: 'Mid')
          @manifestation_late = create(:manifestation, created_at: Time.parse('2020-01-01'), title: 'Late')
        end
      end

      context 'when default sort direction is requested' do
        let(:sort_dir) { 'default'}
        it 'sorts in descending order by default' do
          result_ids = SearchManifestations.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [@manifestation_late.id, @manifestation_mid.id, @manifestation_early.id]
        end
      end

      context 'when asc sort direction is requested' do
        let(:sort_dir) { 'asc'}
        it 'sorts in ascending order' do
          result_ids = SearchManifestations.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [@manifestation_early.id, @manifestation_mid.id, @manifestation_late.id]
        end
      end

      context 'when desc sort direction is requested' do
        let(:sort_dir) { 'desc'}
        it 'sorts in descending order' do
          result_ids = SearchManifestations.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [@manifestation_late.id, @manifestation_mid.id, @manifestation_early.id]
        end
      end
    end
  end

  private

  def assert_date_range(expected_count)
    expect(subject.count).to eq expected_count
    from = Time.parse("#{range['from']}-01-01") if range['from'].present?
    to = Time.parse("#{range['to']}-12-31 23:59:59") if range['to'].present?
    subject.each do |rec|
      time = Time.parse(rec.send(index_attr))
      if from.present?
        expect(time).to be >= from
      end
      if to.present?
        expect(time).to be <= to
      end
    end
  end
end
