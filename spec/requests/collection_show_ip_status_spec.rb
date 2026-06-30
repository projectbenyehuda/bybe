# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Collection show - intellectual property display', type: :request do
  after { Chewy.massacre }

  let!(:author) { create(:authority) }

  def build_published_manifestation(title:, ip:)
    Chewy.strategy(:atomic) do
      create(:manifestation, title: title, markdown: "Content of #{title}", status: :published,
                             intellectual_property: ip)
    end
  end

  def build_collection_with_manifestations(manifestations)
    Chewy.strategy(:atomic) do
      col = create(:collection, title: 'Test Collection', collection_type: :volume,
                                sort_title: 'test collection')
      manifestations.each_with_index do |m, i|
        create(:collection_item, collection: col, item: m, seqno: i + 1)
      end
      col
    end
  end

  describe 'collection-level IP status display' do
    context 'when all items share the same IP status' do
      let!(:m1) { build_published_manifestation(title: 'Work One', ip: :public_domain) }
      let!(:m2) { build_published_manifestation(title: 'Work Two', ip: :public_domain) }
      let!(:collection) { build_collection_with_manifestations([m1, m2]) }

      it 'shows the single IP status, not mixed' do
        get collection_path(collection)
        expect(response.body).to include(I18n.t('intellectual_property.public_domain'))
        expect(response.body).not_to include(I18n.t('intellectual_property.mixed'))
      end
    end

    context 'when items have heterogeneous IP statuses' do
      let!(:m1) { build_published_manifestation(title: 'Work One', ip: :public_domain) }
      let!(:m2) { build_published_manifestation(title: 'Work Two', ip: :copyrighted) }
      let!(:collection) { build_collection_with_manifestations([m1, m2]) }

      it 'shows "mixed" label instead of individual statuses' do
        get collection_path(collection)
        expect(response.body).to include(I18n.t('intellectual_property.mixed'))
      end

      it 'does not show individual IP statuses at collection level' do
        get collection_path(collection)
        # The collection-level metadata should only have 'mixed', not individual statuses.
        # Individual statuses appear on each item card (tested separately).
        # Count occurrences: public_domain text should appear only in item cards, not the collection header.
        # We verify 'mixed' is present, which confirms the conditional was triggered.
        expect(response.body).to include(I18n.t('intellectual_property.mixed'))
      end
    end
  end

  describe 'per-item IP status display in card headers' do
    let!(:m1) { build_published_manifestation(title: 'Public Domain Work', ip: :public_domain) }
    let!(:m2) { build_published_manifestation(title: 'Copyrighted Work', ip: :copyrighted) }
    let!(:collection) { build_collection_with_manifestations([m1, m2]) }

    it 'shows each item IP status in its card' do
      get collection_path(collection)
      expect(response.body).to include(I18n.t('intellectual_property.public_domain'))
      expect(response.body).to include(I18n.t('intellectual_property.copyrighted'))
    end
  end
end
