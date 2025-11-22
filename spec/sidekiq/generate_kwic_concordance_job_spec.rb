# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe GenerateKwicConcordanceJob, type: :job do
  describe '.in_progress?' do
    let(:authority) { create(:authority, status: :published) }
    let(:collection) { create(:collection) }

    context 'when no job is queued or running' do
      it 'returns false for Authority' do
        expect(GenerateKwicConcordanceJob.in_progress?('Authority', authority.id)).to be false
      end

      it 'returns false for Collection' do
        expect(GenerateKwicConcordanceJob.in_progress?('Collection', collection.id)).to be false
      end
    end

    context 'when job is queued' do
      before do
        Sidekiq::Testing.fake! do
          GenerateKwicConcordanceJob.perform_async('Authority', authority.id)
        end
      end

      after do
        Sidekiq::Worker.clear_all
      end

      it 'returns true for the queued Authority job' do
        expect(GenerateKwicConcordanceJob.in_progress?('Authority', authority.id)).to be true
      end

      it 'returns false for different entity' do
        other_authority = create(:authority, status: :published)
        expect(GenerateKwicConcordanceJob.in_progress?('Authority', other_authority.id)).to be false
      end

      it 'returns false for different entity type' do
        expect(GenerateKwicConcordanceJob.in_progress?('Collection', authority.id)).to be false
      end
    end

    context 'when multiple jobs are queued' do
      let(:authority2) { create(:authority, status: :published) }
      let(:collection2) { create(:collection) }

      before do
        Sidekiq::Testing.fake! do
          GenerateKwicConcordanceJob.perform_async('Authority', authority.id)
          GenerateKwicConcordanceJob.perform_async('Authority', authority2.id)
          GenerateKwicConcordanceJob.perform_async('Collection', collection.id)
          GenerateKwicConcordanceJob.perform_async('Collection', collection2.id)
        end
      end

      after do
        Sidekiq::Worker.clear_all
      end

      it 'correctly identifies each queued job' do
        expect(GenerateKwicConcordanceJob.in_progress?('Authority', authority.id)).to be true
        expect(GenerateKwicConcordanceJob.in_progress?('Authority', authority2.id)).to be true
        expect(GenerateKwicConcordanceJob.in_progress?('Collection', collection.id)).to be true
        expect(GenerateKwicConcordanceJob.in_progress?('Collection', collection2.id)).to be true
      end
    end
  end

  describe '#perform' do
    context 'for Authority' do
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
          GenerateKwicConcordanceJob.new.perform('Authority', authority.id)
        end.to change { authority.downloadables.count }.by(1)
      end

      it 'creates a kwic downloadable' do
        GenerateKwicConcordanceJob.new.perform('Authority', authority.id)
        downloadable = authority.downloadables.find_by(doctype: 'kwic')
        expect(downloadable).to be_present
      end
    end

    context 'for Collection' do
      let(:collection) { create(:collection, title: 'Test Collection') }
      let(:manifestation) do
        create(:manifestation, title: 'Test Work', markdown: 'Test content.')
      end

      before do
        create(:collection_item, collection: collection, item: manifestation)
      end

      it 'creates a downloadable for the collection' do
        expect do
          GenerateKwicConcordanceJob.new.perform('Collection', collection.id)
        end.to change { collection.downloadables.count }.by(1)
      end

      it 'creates a kwic downloadable' do
        GenerateKwicConcordanceJob.new.perform('Collection', collection.id)
        downloadable = collection.downloadables.find_by(doctype: 'kwic')
        expect(downloadable).to be_present
      end
    end

    context 'with non-existent entity' do
      it 'logs error and does not raise for Authority' do
        expect(Rails.logger).to receive(:error).with(/not found/)
        expect do
          GenerateKwicConcordanceJob.new.perform('Authority', 999_999)
        end.not_to raise_error
      end

      it 'logs error and does not raise for Collection' do
        expect(Rails.logger).to receive(:error).with(/not found/)
        expect do
          GenerateKwicConcordanceJob.new.perform('Collection', 999_999)
        end.not_to raise_error
      end
    end

    context 'with unsupported entity type' do
      let(:manifestation) { create(:manifestation) }

      it 'raises ArgumentError' do
        expect do
          GenerateKwicConcordanceJob.new.perform('Manifestation', manifestation.id)
        end.to raise_error(ArgumentError, /Unsupported entity type/)
      end
    end
  end
end
