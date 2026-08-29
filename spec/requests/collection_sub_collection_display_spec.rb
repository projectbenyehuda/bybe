# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Collection show - sub-collection headings', type: :request do
  after { Chewy.massacre }

  let(:sub_collection) do
    Chewy.strategy(:atomic) do
      create(:collection, title: 'Sub Collection', subtitle: 'The Subtitle', collection_type: :volume,
                          manifestations: create_list(:manifestation, 2, status: :published))
    end
  end

  let(:parent_collection) do
    Chewy.strategy(:atomic) do
      create(:collection, title: 'Parent Collection', collection_type: :other,
                          included_collections: [sub_collection])
    end
  end

  def attach_cover(collection)
    collection.cover_image.attach(io: StringIO.new(Rails.root.join('spec/fixtures/files/test_image.jpg').binread),
                                  filename: 'cover.jpg', content_type: 'image/jpeg')
  end

  # The header of the sub-collection's own card, i.e. the block ending at the horizontal rule
  def sub_collection_header(html)
    Nokogiri::HTML(html).at_css("a[name='collection_#{sub_collection.id}'] + .by-card-v02 .by-card-header-v02")
  end

  it "shows the sub-collection's subtitle right after its title" do
    get collection_path(parent_collection)
    header = sub_collection_header(response.body)
    expect(header).to be_present
    expect(header.at_css('.headline-1-v02').text).to include('Sub Collection: The Subtitle')
  end

  it "shows the sub-collection's image inside the header, above the horizontal rule" do
    attach_cover(sub_collection)
    get collection_path(parent_collection)
    header = sub_collection_header(response.body)
    expect(header.at_css('img.subcollection-cover-image')).to be_present
  end

  it 'shows no image when the sub-collection has none attached' do
    get collection_path(parent_collection)
    header = sub_collection_header(response.body)
    expect(header.at_css('img.subcollection-cover-image')).to be_nil
  end

  context 'when the sub-collection has no subtitle' do
    let(:sub_collection) do
      Chewy.strategy(:atomic) do
        create(:collection, title: 'Bare Collection', subtitle: nil, collection_type: :volume,
                            manifestations: create_list(:manifestation, 2, status: :published))
      end
    end

    it 'shows the title without a trailing colon' do
      get collection_path(parent_collection)
      header = sub_collection_header(response.body)
      expect(header.at_css('.headline-1-v02').text).to include('Bare Collection')
      expect(header.at_css('.headline-1-v02').text).not_to include('Bare Collection:')
    end
  end
end
