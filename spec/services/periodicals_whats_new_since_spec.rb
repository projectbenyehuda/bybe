# frozen_string_literal: true

require 'rails_helper'

describe PeriodicalsWhatsNewSince do
  describe '#call' do
    subject(:result) { described_class.call(timestamp) }

    let(:author) { create(:authority) }
    let(:translator) { create(:authority) }
    let(:foreign_author) { create(:authority) }

    let(:periodical_issue) { create(:collection, collection_type: 'periodical_issue') }

    let!(:periodical_works) do
      works = create_list(
        :manifestation,
        3,
        author: author,
        orig_lang: 'he',
        created_at: 2.weeks.ago
      )
      # Add manifestations to the periodical issue
      works.each do |work|
        create(:collection_item, collection: periodical_issue, item: work)
      end
      works
    end

    let!(:periodical_translations) do
      works = create_list(
        :manifestation,
        2,
        author: foreign_author,
        translator: translator,
        orig_lang: 'de',
        created_at: 3.weeks.ago
      )
      # Add manifestations to the periodical issue
      works.each do |work|
        create(:collection_item, collection: periodical_issue, item: work)
      end
      works
    end

    let!(:non_periodical_works) do
      # Create works not in periodicals (should not be included)
      create_list(
        :manifestation,
        2,
        author: author,
        orig_lang: 'he',
        created_at: 2.weeks.ago
      )
    end

    context 'when there are no new publications in periodicals' do
      let(:timestamp) { 5.days.ago }

      it { is_expected.to be_empty }
    end

    context 'when there are new periodical publications' do
      let(:timestamp) { 15.days.ago }

      it 'returns only manifestations from periodicals grouped by author and genre' do
        expect(result.keys).to contain_exactly(author)
        expect(result[author].keys).to match_array(periodical_works.map(&:genre).uniq + [:latest])
      end

      it 'does not include non-periodical works' do
        all_returned_manifestations = result.values.flat_map do |author_works|
          author_works.except(:latest).values.flatten
        end
        expect(all_returned_manifestations).not_to include(*non_periodical_works)
      end
    end

    context 'when there are new periodical publications including translations' do
      let(:timestamp) { 1.month.ago }

      it 'returns manifestations grouped by author/translator and genre' do
        expect(result.keys).to contain_exactly(author, translator)
        expect(result[author].keys).to match_array(periodical_works.map(&:genre).uniq + [:latest])
        expect(result[translator].keys).to match_array(periodical_translations.map(&:genre).uniq + [:latest])
      end

      it 'includes all periodical works in the results' do
        all_returned_manifestations = result.values.flat_map do |author_works|
          author_works.except(:latest).values.flatten
        end
        expect(all_returned_manifestations).to match_array(periodical_works + periodical_translations)
      end
    end
  end
end
