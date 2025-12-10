# frozen_string_literal: true

require 'rails_helper'

describe SearchCollections do
  after do
    Chewy.massacre
  end

  describe 'filtering' do
    subject!(:result) { described_class.call(sort_by, sort_dir, filter) }

    let(:result_ids) { result.map(&:id) }
    let(:sort_by) { 'alphabetical' }
    let(:sort_dir) { 'asc' }

    describe 'by collection_types' do
      let(:filter) { { 'collection_types' => collection_types } }
      let(:volume_1) { create(:collection, collection_type: :volume) }
      let(:volume_2) { create(:collection, collection_type: :volume) }
      let(:periodical) { create(:collection, collection_type: :periodical) }
      let(:series) { create(:collection, collection_type: :series) }

      before do
        Chewy.strategy(:atomic) do
          volume_1
          volume_2
          periodical
          series
        end
      end

      context 'when single collection type specified' do
        let(:collection_types) { %w(volume) }

        it 'returns all collections where collection_type is equal to provided value' do
          expect(result_ids).to contain_exactly(volume_1.id, volume_2.id)
        end
      end

      context 'when multiple collection types specified' do
        let(:collection_types) { %w(volume periodical) }

        it 'returns all collections where collection_type is included in provided list' do
          expect(result_ids).to contain_exactly(volume_1.id, volume_2.id, periodical.id)
        end
      end
    end

    describe 'by authority_ids' do
      let(:filter) { { 'authority_ids' => authority_ids } }

      context 'when authority id is provided' do
        let(:target_authority) { create(:authority, name: 'John Smith') }
        let(:other_authority) { create(:authority, name: 'Jane Doe') }
        let(:authority_ids) { [target_authority.id] }
        let(:target_1) { create(:collection, collection_type: :volume) }
        let(:target_2) { create(:collection, collection_type: :series) }
        let(:other) { create(:collection, collection_type: :periodical) }

        before do
          target_1.involved_authorities.create!(authority: target_authority, role: 'author')
          target_2.involved_authorities.create!(authority: target_authority, role: 'editor')
          other.involved_authorities.create!(authority: other_authority, role: 'author')

          Chewy.strategy(:atomic) do
            target_1
            target_2
            other
          end
        end

        it 'returns all collections with this authority' do
          expect(result_ids).to contain_exactly(target_1.id, target_2.id)
        end
      end

      context 'when multiple authority ids are provided' do
        let(:authority_1) { create(:authority, name: 'Author One') }
        let(:authority_2) { create(:authority, name: 'Author Two') }
        let(:authority_3) { create(:authority, name: 'Author Three') }
        let(:authority_ids) { [authority_1.id, authority_2.id] }
        let(:coll_1) { create(:collection, collection_type: :volume) }
        let(:coll_2) { create(:collection, collection_type: :series) }
        let(:coll_3) { create(:collection, collection_type: :periodical) }

        before do
          coll_1.involved_authorities.create!(authority: authority_1, role: 'author')
          coll_2.involved_authorities.create!(authority: authority_2, role: 'editor')
          coll_3.involved_authorities.create!(authority: authority_3, role: 'author')

          Chewy.strategy(:atomic) do
            coll_1
            coll_2
            coll_3
          end
        end

        it 'returns all collections with any of the specified authorities' do
          expect(result_ids).to contain_exactly(coll_1.id, coll_2.id)
        end
      end
    end

    describe 'by tags' do
      let(:filter) { { 'tags' => tags } }
      let(:tag_1) { create(:tag, name: 'Hebrew Literature') }
      let(:tag_2) { create(:tag, name: 'Poetry') }
      let(:tag_3) { create(:tag, name: 'Modern') }
      let(:coll_1) { create(:collection, collection_type: :volume) }
      let(:coll_2) { create(:collection, collection_type: :series) }
      let(:coll_3) { create(:collection, collection_type: :periodical) }

      before do
        coll_1.taggings.create!(tag: tag_1)
        coll_2.taggings.create!(tag: tag_2)
        coll_3.taggings.create!(tag: tag_3)

        Chewy.strategy(:atomic) do
          coll_1
          coll_2
          coll_3
        end
      end

      context 'when single tag name specified' do
        let(:tags) { ['Hebrew Literature'] }

        it 'returns all collections with that tag' do
          expect(result_ids).to contain_exactly(coll_1.id)
        end
      end

      context 'when multiple tags specified' do
        let(:tags) { ['Hebrew Literature', 'Poetry'] }

        it 'returns all collections with any of those tags' do
          expect(result_ids).to contain_exactly(coll_1.id, coll_2.id)
        end
      end
    end

    describe 'by publication date' do
      let(:filter) { { 'publication_date_between' => range } }
      let(:coll_1980) { create(:collection, normalized_pub_year: 1980) }
      let(:coll_1985) { create(:collection, normalized_pub_year: 1985) }
      let(:coll_1990) { create(:collection, normalized_pub_year: 1990) }
      let(:coll_1995_inception) { create(:collection, inception_year: 1995) }
      let(:coll_2000) { create(:collection, normalized_pub_year: 2000) }

      before do
        Chewy.strategy(:atomic) do
          coll_1980
          coll_1985
          coll_1990
          coll_1995_inception
          coll_2000
        end
      end

      context "when 'from' and 'to' values are equal" do
        let(:range) { { 'from' => 1990, 'to' => 1990 } }

        it 'returns all collections published in given year' do
          expect(result_ids).to contain_exactly(coll_1990.id)
        end
      end

      context "when 'from' and 'to' values are different" do
        let(:range) { { 'from' => 1985, 'to' => 1995 } }

        it 'returns all collections published in given range' do
          expect(result_ids).to contain_exactly(coll_1985.id, coll_1990.id, coll_1995_inception.id)
        end
      end

      context "when only 'from' value provided" do
        let(:range) { { 'from' => 1990 } }

        it 'returns all collections published starting from given year' do
          expect(result_ids).to contain_exactly(coll_1990.id, coll_1995_inception.id, coll_2000.id)
        end
      end

      context "when only 'to' value provided" do
        let(:range) { { 'to' => 1990 } }

        it 'returns all collections published before or in given year' do
          expect(result_ids).to contain_exactly(coll_1980.id, coll_1985.id, coll_1990.id)
        end
      end
    end

    describe 'by title' do
      let(:filter) { { 'title' => title } }

      context 'when single word is provided' do
        let(:title) { 'Hebrew' }
        let(:hebrew_poetry) { create(:collection, title: 'Hebrew Poetry Collection') }
        let(:modern_hebrew) { create(:collection, title: 'The Modern Hebrew Literature') }
        let(:yiddish_works) { create(:collection, title: 'Yiddish Literary Works') }

        before do
          Chewy.strategy(:atomic) do
            hebrew_poetry
            modern_hebrew
            yiddish_works
          end
        end

        it 'returns all collections including given word in title' do
          expect(result_ids).to contain_exactly(hebrew_poetry.id, modern_hebrew.id)
        end
      end

      context 'when multiple words are provided' do
        let(:title) { 'Modern Hebrew' }
        let(:modern_hebrew_poetry) { create(:collection, title: 'Modern Hebrew Poetry') }
        let(:modern_hebrew_prose) { create(:collection, title: 'Modern Hebrew Prose Collection') }
        let(:hebrew_modern_literature) { create(:collection, title: 'Hebrew Modern Literature') }

        before do
          Chewy.strategy(:atomic) do
            modern_hebrew_poetry
            modern_hebrew_prose
            hebrew_modern_literature
          end
        end

        it 'returns all collections having all these words in same order' do
          expect(result_ids).to contain_exactly(modern_hebrew_poetry.id, modern_hebrew_prose.id)
        end
      end
    end
  end

  describe 'sorting' do
    describe 'alphabetical' do
      let(:sorting) { 'alphabetical' }
      let(:coll_a) { create(:collection, title: 'Alpha Collection', sort_title: 'alpha collection') }
      let(:coll_b) { create(:collection, title: 'Beta Series', sort_title: 'beta series') }
      let(:coll_c) { create(:collection, title: 'Gamma Works', sort_title: 'gamma works') }

      before do
        Chewy.strategy(:atomic) do
          coll_a
          coll_b
          coll_c
        end
      end

      context 'when default sort direction is requested' do
        let(:sort_dir) { 'default' }

        it 'sorts in ascending order' do
          result_ids = described_class.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [coll_a.id, coll_b.id, coll_c.id]
        end
      end

      context 'when asc sort direction is requested' do
        let(:sort_dir) { 'asc' }

        it 'sorts in ascending order' do
          result_ids = described_class.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [coll_a.id, coll_b.id, coll_c.id]
        end
      end

      context 'when desc sort direction is requested' do
        let(:sort_dir) { 'desc' }

        it 'sorts in descending order' do
          result_ids = described_class.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [coll_c.id, coll_b.id, coll_a.id]
        end
      end
    end

    describe 'popularity' do
      let(:sorting) { 'popularity' }
      let(:coll_low) { create(:collection, impressions_count: 10) }
      let(:coll_mid) { create(:collection, impressions_count: 50) }
      let(:coll_high) { create(:collection, impressions_count: 100) }

      before do
        Chewy.strategy(:atomic) do
          coll_low
          coll_mid
          coll_high
        end
      end

      context 'when default sort direction is requested' do
        let(:sort_dir) { 'default' }

        it 'sorts in descending order by default' do
          result_ids = described_class.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [coll_high.id, coll_mid.id, coll_low.id]
        end
      end

      context 'when asc sort direction is requested' do
        let(:sort_dir) { 'asc' }

        it 'sorts in ascending order' do
          result_ids = described_class.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [coll_low.id, coll_mid.id, coll_high.id]
        end
      end

      context 'when desc sort direction is requested' do
        let(:sort_dir) { 'desc' }

        it 'sorts in descending order' do
          result_ids = described_class.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [coll_high.id, coll_mid.id, coll_low.id]
        end
      end
    end

    describe 'publication_date' do
      let(:sorting) { 'publication_date' }
      let(:coll_early) { create(:collection, normalized_pub_year: 1980) }
      let(:coll_mid) { create(:collection, normalized_pub_year: 1990) }
      let(:coll_late) { create(:collection, normalized_pub_year: 2000) }

      before do
        Chewy.strategy(:atomic) do
          coll_early
          coll_mid
          coll_late
        end
      end

      context 'when default sort direction is requested' do
        let(:sort_dir) { 'default' }

        it 'sorts in ascending order by default' do
          result_ids = described_class.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [coll_early.id, coll_mid.id, coll_late.id]
        end
      end

      context 'when asc sort direction is requested' do
        let(:sort_dir) { 'asc' }

        it 'sorts in ascending order' do
          result_ids = described_class.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [coll_early.id, coll_mid.id, coll_late.id]
        end
      end

      context 'when desc sort direction is requested' do
        let(:sort_dir) { 'desc' }

        it 'sorts in descending order' do
          result_ids = described_class.call(sorting, sort_dir, {}).map(&:id)
          expect(result_ids).to eq [coll_late.id, coll_mid.id, coll_early.id]
        end
      end
    end
  end
end
