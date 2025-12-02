# frozen_string_literal: true

require 'rails_helper'

describe WhatsNewSince do
  describe '#call' do
    subject(:result) { described_class.call(timestamp) }

    let(:author) { create(:authority) }
    let(:translator) { create(:authority) }
    let(:foreign_author) { create(:authority) }

    let!(:original_works) do
      create_list(
        :manifestation,
        3,
        author: author,
        orig_lang: 'he',
        created_at: 2.weeks.ago
      )
    end

    let!(:translated_works) do
      create_list(
        :manifestation,
        2,
        author: foreign_author,
        translator: translator,
        orig_lang: 'de',
        created_at: 3.weeks.ago
      )
    end

    context 'when there are no new publications' do
      let(:timestamp) { 5.days.ago }

      it { is_expected.to be_empty }
    end

    context 'when there are new original publications' do
      let(:timestamp) { 15.days.ago }

      it 'returns manifestations grouped by author and genre' do
        expect(result[author].keys).to match_array(original_works.map(&:genre).uniq + [:latest])
      end
    end

    context 'when there are new original and translated publications' do
      let(:timestamp) { 1.month.ago }

      it 'returns manifestations grouped by author/translator and genre' do
        expect(result.keys).to contain_exactly(author, translator)
        expect(result[author].keys).to match_array(original_works.map(&:genre).uniq + [:latest])
        expect(result[translator].keys).to match_array(translated_works.map(&:genre).uniq + [:latest])
      end
    end
  end
end
