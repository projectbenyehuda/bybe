# frozen_string_literal: true

require 'rails_helper'

describe ExternalLink do
  describe 'url validation' do
    it 'requires a url for non-publisher_site links' do
      link = build(:external_link, linktype: :blog, url: '')
      expect(link).not_to be_valid
      expect(link.errors[:url]).to be_present
    end

    it 'allows nil or empty url for publisher_site links' do
      [nil, ''].each do |blank_url|
        link = build(:external_link, linktype: :publisher_site, url: blank_url, description: 'Some Publisher')
        expect(link).to be_valid
      end
    end
  end
end
