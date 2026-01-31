# frozen_string_literal: true

require 'rails_helper'

describe RandomAuthor do
  describe '#call' do
    before do
      clean_tables
      create_list(:manifestation, 5, status: :published, genre: :drama)
      create_list(:manifestation, 5, status: :published, genre: :poetry)
      create_list(:manifestation, 5, status: :published, genre: :lexicon)
    end

    context 'when genre is not provided' do
      subject { described_class.call }

      it { is_expected.to be_an Authority }
    end

    context 'when genre is provided' do
      subject { described_class.call('fables') }

      let!(:fable) { create(:manifestation, genre: :fables) }

      it { is_expected.to eq fable.authors.first }
    end

    context 'when authority has do_not_feature flag' do
      before do
        clean_tables
        # Create authority with do_not_feature = true
        non_featurable_manifestation = create(:manifestation, status: :published)
        non_featurable_manifestation.authors.first.update!(do_not_feature: true)

        # Create featurable authority
        create(:manifestation, status: :published)
      end

      it 'excludes authorities with do_not_feature flag' do
        # Call multiple times to ensure we never get the non-featurable authority
        results = 10.times.map { described_class.call }
        non_featurable_ids = Authority.where(do_not_feature: true).pluck(:id)

        results.each do |result|
          expect(non_featurable_ids).not_to include(result.id)
        end
      end
    end
  end
end
