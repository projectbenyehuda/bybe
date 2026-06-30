# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Collection show - intellectual property display', type: :request do
  after { Chewy.massacre }

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

  # Returns the text content of the collection info card (.work-info-card), which
  # is the only place where the collection-level IP status should appear.
  def info_card_text(html)
    Nokogiri::HTML(html).at_css('.work-info-card')&.text || ''
  end

  describe 'collection-level IP status display' do
    context 'when all items share the same IP status' do
      let!(:m1) { build_published_manifestation(title: 'Work One', ip: :public_domain) }
      let!(:m2) { build_published_manifestation(title: 'Work Two', ip: :public_domain) }
      let!(:collection) { build_collection_with_manifestations([m1, m2]) }

      it 'shows the single IP status in the collection info card, not mixed' do
        get collection_path(collection)
        card = info_card_text(response.body)
        expect(card).to include(I18n.t('intellectual_property.public_domain'))
        expect(card).not_to include(I18n.t('intellectual_property.mixed'))
      end
    end

    context 'when items have heterogeneous IP statuses' do
      let!(:m1) { build_published_manifestation(title: 'Work One', ip: :public_domain) }
      let!(:m2) { build_published_manifestation(title: 'Work Two', ip: :copyrighted) }
      let!(:collection) { build_collection_with_manifestations([m1, m2]) }

      it 'shows only the mixed label in the collection info card, not individual statuses' do
        get collection_path(collection)
        card = info_card_text(response.body)
        expect(card).to include(I18n.t('intellectual_property.mixed'))
        expect(card).not_to include(I18n.t('intellectual_property.public_domain'))
        expect(card).not_to include(I18n.t('intellectual_property.copyrighted'))
      end
    end
  end

  describe 'per-item IP status display in card headers' do
    let!(:m1) { build_published_manifestation(title: 'Public Domain Work', ip: :public_domain) }
    let!(:m2) { build_published_manifestation(title: 'Copyrighted Work', ip: :copyrighted) }
    let!(:collection) { build_collection_with_manifestations([m1, m2]) }

    it 'shows each item IP status in its own card' do
      get collection_path(collection)
      doc = Nokogiri::HTML(response.body)
      item_cards_text = doc.css('.proofable').map(&:text).join
      expect(item_cards_text).to include(I18n.t('intellectual_property.public_domain'))
      expect(item_cards_text).to include(I18n.t('intellectual_property.copyrighted'))
    end
  end
end
