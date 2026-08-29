# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Collection reading mode', type: :request do
  after { Chewy.massacre }

  let!(:author) { create(:authority, name: 'Author Name') }

  let!(:m1) do
    Chewy.strategy(:atomic) do
      create(:manifestation, title: 'First Text', markdown: 'Body of the first text', status: :published)
    end
  end

  let!(:m2) do
    Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Second Text', markdown: 'Body of the second text', status: :published)
    end
  end

  let!(:collection) do
    Chewy.strategy(:atomic) do
      col = create(:collection, title: 'Readable Collection', collection_type: :volume)
      create(:involved_authority, item: col, authority: author, role: 'author')
      create(:collection_item, collection: col, item: m1, seqno: 1)
      create(:collection_item, collection: col, item: m2, seqno: 2)
      col
    end
  end

  describe 'GET /collections/:collection_id/readmode' do
    it 'renders the collection texts without the site header and footer' do
      get collection_readmode_path(collection)

      expect(response).to have_http_status(:success)
      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css('.reading-mode')).to be_present
      expect(doc.at_css('header')).to be_nil
      expect(doc.at_css('footer')).to be_nil
      expect(response.body).to include('Body of the first text')
      expect(response.body).to include('Body of the second text')
    end

    it 'offers a way back to the collection page and marks itself noindex' do
      get collection_readmode_path(collection)

      doc = Nokogiri::HTML(response.body)
      expect(doc.css("a.collapse-expand-icon[href='#{collection_path(collection)}']")).to be_present
      expect(doc.at_css("meta[name='robots'][content='noindex']")).to be_present
    end

    it 'lists the collection items in the reading-mode item selector' do
      get collection_readmode_path(collection)

      options = Nokogiri::HTML(response.body).css('select#collitem option')
      expect(options.map(&:text)).to eq(['First Text', 'Second Text'])
    end

    it 'is reachable by anonymous visitors' do
      get collection_readmode_path(collection)
      expect(response).to have_http_status(:success)
    end
  end

  describe 'the reading-mode buttons on Collection#show' do
    it 'links the desktop button and the mobile icon button to the reading mode' do
      get collection_path(collection)

      doc = Nokogiri::HTML(response.body)
      readmode_href = collection_readmode_path(collection)

      desktop = doc.at_css(".work-page-top-icons-desktop a[href='#{readmode_href}']")
      expect(desktop).to be_present
      expect(desktop.at_css('.reading-mode-btn-v02')).to be_present

      mobile = doc.at_css(".work-page-top-icons-mobile a[href='#{readmode_href}']")
      expect(mobile).to be_present
      expect(mobile['class']).to include('reading-mode-icon-btn-v02')
    end
  end
end
