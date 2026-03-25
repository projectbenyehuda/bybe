# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#staging?' do
    around do |example|
      original_upper = ENV['CACHE_NONCE']
      original_lower = ENV['cache_nonce']
      example.run
      ENV['CACHE_NONCE'] = original_upper
      ENV['cache_nonce'] = original_lower
    end

    it 'returns true when CACHE_NONCE is staging' do
      ENV['CACHE_NONCE'] = 'staging'
      ENV['cache_nonce'] = nil
      expect(helper.staging?).to be true
    end

    it 'returns true when cache_nonce (lowercase) is staging' do
      ENV['CACHE_NONCE'] = nil
      ENV['cache_nonce'] = 'staging'
      expect(helper.staging?).to be true
    end

    it 'returns false when neither env var is set' do
      ENV['CACHE_NONCE'] = nil
      ENV['cache_nonce'] = nil
      expect(helper.staging?).to be false
    end

    it 'returns false when CACHE_NONCE is set to a different value' do
      ENV['CACHE_NONCE'] = 'production'
      ENV['cache_nonce'] = nil
      expect(helper.staging?).to be false
    end
  end

  describe '#update_param' do
    it 'updates a parameter in a simple URL' do
      url = 'https://example.com/path?foo=bar'
      result = helper.update_param(url, 'baz', 'qux')
      uri = Addressable::URI.parse(result)
      params = uri.query_values
      expect(params['foo']).to eq('bar')
      expect(params['baz']).to eq('qux')
    end

    it 'updates an existing parameter' do
      url = 'https://example.com/path?foo=bar&baz=old'
      result = helper.update_param(url, 'baz', 'new')
      uri = Addressable::URI.parse(result)
      params = uri.query_values
      expect(params['foo']).to eq('bar')
      expect(params['baz']).to eq('new')
    end

    it 'handles URLs without query parameters' do
      url = 'https://example.com/path'
      result = helper.update_param(url, 'foo', 'bar')
      expect(result).to eq('https://example.com/path?foo=bar')
    end

    it 'handles URLs with non-ASCII characters (Hebrew)' do
      # Test the exact case from the bug report: Hebrew letter פ
      # \xD7\xA4 is UTF-8 encoding for פ
      url = "https://benyehuda.org/dict/24412?page=112&to_letter=\xD7\xA4"
      result = helper.update_param(url, 'page', '113')

      # The result should have the page updated and preserve the Hebrew character
      expect(result).to include('page=113')
      expect(result).to include('to_letter=')
      # Check that the URL is valid and doesn't raise an error
      expect { URI.parse(result) }.not_to raise_error
    end

    it 'properly percent-encodes non-ASCII characters' do
      url = 'https://example.com/path?letter=א'
      result = helper.update_param(url, 'page', '1')

      # The Hebrew letter א should be percent-encoded
      expect(result).to include('page=1')
      expect(result).to include('letter=')
    end

    it 'handles multiple non-ASCII characters' do
      url = 'https://example.com/path?term=שלום&lang=he'
      result = helper.update_param(url, 'page', '2')

      expect(result).to include('page=2')
      expect(result).to include('term=')
      expect(result).to include('lang=he')
    end
  end
end
