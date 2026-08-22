# frozen_string_literal: true

require 'rails_helper'

describe Ahoy::Event do
  describe '.download_counts_by_format' do
    subject(:counts) { described_class.download_counts_by_format(2.months.ago, Time.current) }

    let(:manifestation) { create(:manifestation) }
    let(:collection) { create(:collection) }

    it 'returns an empty hash when there are no download events' do
      create(:ahoy_event, :with_item, name: 'view', item: manifestation, time: 1.day.ago)

      expect(counts).to eq({})
    end

    it 'counts downloads grouped by format and item type' do
      create_list(:ahoy_event, 3, :with_item, name: 'download', item: manifestation, doctype: 'epub',
                                              time: 1.day.ago)
      create(:ahoy_event, :with_item, name: 'download', item: manifestation, doctype: 'pdf', time: 1.day.ago)
      create_list(:ahoy_event, 2, :with_item, name: 'download', item: collection, doctype: 'epub', time: 1.day.ago)

      expect(counts).to eq(
        %w(epub Manifestation) => 3,
        %w(pdf Manifestation) => 1,
        %w(epub Collection) => 2
      )
    end

    it 'ignores events of other names' do
      create(:ahoy_event, :with_item, name: 'view', item: manifestation, time: 1.day.ago)
      create(:ahoy_event, :with_item, name: 'download', item: manifestation, doctype: 'docx', time: 1.day.ago)

      expect(counts).to eq(%w(docx Manifestation) => 1)
    end

    it 'ignores events outside the given time range' do
      create(:ahoy_event, :with_item, name: 'download', item: manifestation, doctype: 'docx', time: 1.day.ago)
      create(:ahoy_event, :with_item, name: 'download', item: manifestation, doctype: 'docx', time: 1.year.ago)

      expect(counts).to eq(%w(docx Manifestation) => 1)
    end

    it 'reports a nil format for legacy events recorded before format tracking' do
      create(:ahoy_event, :with_item, name: 'download', item: manifestation, time: 1.day.ago)

      expect(counts).to eq([nil, 'Manifestation'] => 1)
    end
  end
end
