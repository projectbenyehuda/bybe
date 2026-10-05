# frozen_string_literal: true

require 'rails_helper'

describe 'Collection show - publisher_site link', type: :request do
  after { Chewy.massacre }

  let(:collection) do
    Chewy.strategy(:atomic) do
      create(:collection, title: 'Credited Collection', collection_type: :volume,
                          manifestations: create_list(:manifestation, 2, status: :published))
    end
  end

  it 'shows a publisher_site link without url as plain text, with no link markers' do
    create(:external_link, linkable: collection, linktype: :publisher_site, url: nil,
                           description: 'Plain &&&Publisher&&& Name')

    get collection_path(collection)

    row = Nokogiri::HTML(response.body).css('.metadata').find { |d| d.text.include?('Plain Publisher Name') }
    expect(row).to be_present
    expect(row.css('a')).to be_empty
    expect(row.text).not_to include('&&&')
  end
end
