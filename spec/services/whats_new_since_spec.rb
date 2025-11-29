# frozen_string_literal: true

require 'rails_helper'

describe WhatsNewSince do
  describe '#call' do
    subject(:result) { described_class.call(timestamp) }

    let(:timestamp) { 1.month.ago }

    before do
      clean_tables
    end

    context 'when there are no new publications' do
      it { is_expected.to be_empty }
    end

    context 'when there are new publications' do
      let!(:manifestation) { create(:manifestation, status: :published, updated_at: 1.week.ago, genre: :poetry) }

      it 'returns hash with authority as key' do
        expect(result.keys.first).to be_an(Authority)
      end

      it 'includes manifestations grouped by genre' do
        authority = result.keys.first
        # genre is stored as string in the database
        expect(result[authority]['poetry']).to include(manifestation)
      end

      it 'includes latest timestamp' do
        authority = result.keys.first
        expect(result[authority][:latest]).to eq(manifestation.updated_at)
      end
    end

    context 'when there are translations' do
      let!(:translation) do
        create(
          :manifestation,
          status: :published,
          updated_at: 1.week.ago,
          genre: :poetry,
          orig_lang: 'en',
          language: 'he'
        )
      end

      it 'groups translations by translator' do
        authority = result.keys.first
        expect(authority).to eq(translation.translators.first)
      end
    end
  end
end
