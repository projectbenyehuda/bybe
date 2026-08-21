# frozen_string_literal: true

require 'rails_helper'

# The "made available by" publisher_site line in Manifestation#read's metadata sits in a
# flex row (.metadata is display:flex; align-items:center). When the link text wraps past
# one line, centering drags the bold label out of line with the first line of the value.
# .metadata-top-aligned (align-items: flex-start) keeps the label flush with the first
# line, the same way the source-edition line above it already does.
describe 'Manifestation#read publisher link alignment', type: :request do
  let!(:text) do
    Chewy.strategy(:atomic) do
      create(:manifestation, orig_lang: 'he', status: :published)
    end
  end

  after { Chewy.massacre }

  it 'top-aligns the publisher_site metadata row' do
    create(:external_link, linkable: text, linktype: :publisher_site, url: 'https://example.com',
                           description: 'Some Very Long Publisher Name')

    get manifestation_path(text)

    row = Nokogiri::HTML(response.body).css('.metadata').find do |d|
      d.text.include?('Some Very Long Publisher Name')
    end
    expect(row).to be_present
    expect(row['class'].split).to include('metadata-top-aligned')
  end
end
