# frozen_string_literal: true

require 'rails_helper'

describe BackfillVolumeAuthorities do
  subject(:service) { described_class.call }

  let(:author) { create(:authority) }
  let(:other_author) { create(:authority) }

  def bare_volume(manifestations)
    create(:collection, collection_type: 'volume', manifestations: manifestations).tap do |c|
      c.involved_authorities.destroy_all
    end
  end

  context 'when all manifestations share one author' do
    let!(:volume) { bare_volume(2.times.map { create(:manifestation, author: author) }) }

    it 'assigns that author with the author role, and is idempotent' do
      service
      expect(volume.involved_authorities.reload.map { |ia| [ia.authority, ia.role] }).to eq([[author, 'author']])
      expect(described_class.call.assigned.map(&:collection)).not_to include(volume)
    end

    it 'changes nothing on a dry run' do
      described_class.call(dry_run: true)
      expect(volume.involved_authorities.reload).to be_empty
    end
  end

  context 'when manifestations have different authors' do
    let!(:volume) do
      bare_volume([create(:manifestation, author: author), create(:manifestation, author: other_author)])
    end

    it 'skips the volume and reports it' do
      reported = service.needs_review.find { |r| r.collection == volume }
      expect(reported.reason).to eq('multiple_authorities')
      expect(volume.involved_authorities.reload).to be_empty
    end
  end

  context 'when the shared author is pageless' do
    let!(:volume) { bare_volume([create(:manifestation, author: create(:authority, pageless: true))]) }

    it 'reports it instead of assigning' do
      expect(service.needs_review.find { |r| r.collection == volume }.reason).to eq('pageless_authority')
      expect(volume.involved_authorities.reload).to be_empty
    end
  end

  context 'when the volume is empty' do
    let!(:volume) { bare_volume([]) }

    it 'reports it as having no manifestations' do
      expect(service.needs_review.find { |r| r.collection == volume }.reason).to eq('no_manifestations')
    end
  end

  context 'when the volume already has an involved authority' do
    let!(:volume) do
      create(:collection, collection_type: 'volume', authors: [other_author],
                          manifestations: [create(:manifestation, author: author)])
    end

    it 'is untouched' do
      service
      expect(volume.involved_authorities.reload.map(&:authority)).to eq([other_author])
      expect(service.needs_review.map(&:collection)).not_to include(volume)
    end
  end
end
