# frozen_string_literal: true

require 'rails_helper'

describe GenerateKwicConcordanceJob do
  describe '#perform' do
    context 'with Authority' do
      subject(:call) { described_class.new.perform('Authority', authority.id) }

      let(:authority) { create(:authority, status: :published, kwic_generation_started_at: 5.minutes.ago) }
      let!(:manifestation) do
        create(
          :manifestation,
          author: authority
        )
      end

      it 'creates a downloadable for the authority' do
        expect { call }.to change{ authority.downloadables.count }.by(1)
        downloadable = authority.downloadables.find_by(doctype: 'kwic')
        expect(downloadable).to be_present
        expect(authority.reload.kwic_generation_started_at).to be_nil
      end
    end

    context 'with Collection' do
      subject(:call) { described_class.new.perform('Collection', collection.id) }

      let(:manifestation) { create(:manifestation) }
      let!(:collection) do
        create(:collection, manifestations: [manifestation], kwic_generation_started_at: 5.minutes.ago)
      end

      it 'creates a downloadable for the collection' do
        expect { call }.to change { collection.downloadables.count }.by(1)
        downloadable = collection.downloadables.find_by(doctype: 'kwic')
        expect(downloadable).to be_present
        expect(collection.reload.kwic_generation_started_at).to be_nil
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
