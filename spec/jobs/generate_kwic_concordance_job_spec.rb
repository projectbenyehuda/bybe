# frozen_string_literal: true

require 'rails_helper'

describe GenerateKwicConcordanceJob do
  describe '#perform' do
    let(:job) { described_class.new }

    before do
      allow(job).to receive(:generate_collection_concordance).and_call_original
      allow(job).to receive(:generate_authority_concordance).and_call_original
    end

    context 'with Authority' do
      subject(:call) { job.perform('Authority', authority.id) }

      let(:authority) { create(:authority, status: :published, kwic_generation_started_at: kwic_generation_started_at) }
      let!(:manifestation) do
        create(
          :manifestation,
          author: authority
        )
      end

      context 'when kwic_generation_started_at is set' do
        let(:kwic_generation_started_at) { 5.minutes.ago }

        it 'creates a downloadable for the authority' do
          expect { call }.to change { authority.downloadables.count }.by(1)
          expect(job).to have_received(:generate_authority_concordance).once
          expect(job).not_to have_received(:generate_collection_concordance)
          downloadable = authority.downloadables.find_by(doctype: 'kwic')
          expect(downloadable).to be_present
          expect(authority.reload.kwic_generation_started_at).to be_nil
        end
      end

      context 'when kwic_generation_started_at is nil' do
        let(:kwic_generation_started_at) { nil }

        it 'does nothing' do
          expect { call }.not_to(change { authority.downloadables.count })
          expect(job).not_to have_received(:generate_authority_concordance)
          expect(job).not_to have_received(:generate_collection_concordance)
        end
      end
    end

    context 'with Collection' do
      subject(:call) { job.perform('Collection', collection.id) }

      let(:manifestation) { create(:manifestation) }
      let!(:collection) do
        create(:collection, manifestations: [manifestation], kwic_generation_started_at: kwic_generation_started_at)
      end

      context 'when kwic_generation_started_at is set' do
        let(:kwic_generation_started_at) { 5.minutes.ago }

        it 'creates a downloadable for the collection' do
          expect { call }.to change { collection.downloadables.count }.by(1)
          expect(job).not_to have_received(:generate_authority_concordance)
          expect(job).to have_received(:generate_collection_concordance).once
          downloadable = collection.downloadables.find_by(doctype: 'kwic')
          expect(downloadable).to be_present
          expect(collection.reload.kwic_generation_started_at).to be_nil
        end
      end

      context 'when kwic_generation_started_at is nil' do
        let(:kwic_generation_started_at) { nil }

        it 'does nothing' do
          expect { call }.not_to(change { collection.downloadables.count })
          expect(job).not_to have_received(:generate_authority_concordance)
          expect(job).not_to have_received(:generate_collection_concordance)
        end
      end
    end

    context 'with non-existent entity' do
      it 'logs error and does not raise for Authority' do
        allow(Rails.logger).to receive(:error)
        expect do
          described_class.new.perform('Authority', 999_999)
        end.not_to raise_error
        expect(Rails.logger).to have_received(:error).with(/not found/)
      end

      it 'logs error and does not raise for Collection' do
        allow(Rails.logger).to receive(:error)
        expect do
          described_class.new.perform('Collection', 999_999)
        end.not_to raise_error
        expect(Rails.logger).to have_received(:error).with(/not found/)
      end
    end
  end
end
