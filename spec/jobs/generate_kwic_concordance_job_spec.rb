# frozen_string_literal: true

require 'rails_helper'

describe GenerateKwicConcordanceJob do
  describe '#perform' do
    context 'with Authority' do
      let(:authority) { create(:authority, status: :published) }
      let(:work) { create(:work) }
      let(:expression) { create(:expression, work: work) }
      let(:manifestation) do
        create(
          :manifestation,
          title: 'Test Work',
          markdown: 'Test content.',
          expression: expression,
          status: :published
        )
      end

      before do
        create(:involved_authority, authority: authority, item: work, role: :author)
        manifestation
      end

      it 'creates a downloadable for the authority' do
        expect do
          described_class.new.perform('Authority', authority.id)
        end.to change { authority.downloadables.count }.by(1)
      end

      it 'creates a kwic downloadable' do
        described_class.new.perform('Authority', authority.id)
        downloadable = authority.downloadables.find_by(doctype: 'kwic')
        expect(downloadable).to be_present
      end
    end

    context 'with Collection' do
      let(:collection) { create(:collection, title: 'Test Collection') }
      let(:manifestation) do
        create(:manifestation, title: 'Test Work', markdown: 'Test content.')
      end

      before do
        create(:collection_item, collection: collection, item: manifestation)
      end

      it 'creates a downloadable for the collection' do
        expect do
          described_class.new.perform('Collection', collection.id)
        end.to change { collection.downloadables.count }.by(1)
      end

      it 'creates a kwic downloadable' do
        described_class.new.perform('Collection', collection.id)
        downloadable = collection.downloadables.find_by(doctype: 'kwic')
        expect(downloadable).to be_present
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

    context 'with unsupported entity type' do
      let(:manifestation) { create(:manifestation) }

      it 'raises ArgumentError' do
        expect do
          described_class.new.perform('Manifestation', manifestation.id)
        end.to raise_error(ArgumentError, /Unsupported entity type/)
      end
    end
  end
end
