# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::WaybackLookup do
  include WebMock::API

  subject(:lookup) { described_class.call(url) }

  let(:url) { 'http://example.com/gone' }
  let(:cdx_snapshot) { "https://web.archive.org/web/20190101000000/#{url}" }
  # Each context overrides the response it cares about; by default the Availability API has
  # nothing and the CDX API has a 200 capture.
  let(:availability_response) { { body: { url: url, archived_snapshots: {} }.to_json } }
  let(:cdx_response) { { body: [%w(timestamp original), ['20190101000000', url]].to_json } }
  let!(:availability_request) do
    stub_request(:get, described_class::AVAILABILITY_API_URL).with(query: { url: url })
                                                             .to_return(availability_response)
  end
  let!(:cdx_request) do
    stub_request(:get, described_class::CDX_API_URL).with(query: hash_including(url: url, filter: 'statuscode:200'))
                                                    .to_return(cdx_response)
  end

  before { WebMock.disable_net_connect!(allow_localhost: true) }

  def closest_snapshot(snapshot_url, status: '200', available: true)
    { url: url, archived_snapshots: { closest: { status: status, available: available,
                                                 url: snapshot_url, timestamp: '20200101000000' } } }.to_json
  end

  context 'when the Availability API finds a snapshot' do
    let(:availability_response) { { body: closest_snapshot("http://web.archive.org/web/20200101000000/#{url}") } }

    it 'returns it, upgraded to https, without asking the CDX API' do
      expect(lookup).to eq "https://web.archive.org/web/20200101000000/#{url}"
      assert_not_requested(cdx_request)
    end
  end

  context 'when the Availability API has nothing' do
    it 'returns the last 200 capture from the CDX API' do
      expect(lookup).to eq cdx_snapshot
    end
  end

  # A redirect capture is as often a dead article bounced to a home page as a live one
  context 'when the Availability API offers only a redirect capture' do
    let(:availability_response) { { body: closest_snapshot('http://web.archive.org/web/2020/x', status: '301') } }

    it 'ignores it in favour of the CDX API' do
      expect(lookup).to eq cdx_snapshot
    end
  end

  context 'when the Availability API marks the snapshot unavailable' do
    let(:availability_response) { { body: closest_snapshot('http://web.archive.org/web/2020/x', available: false) } }

    it 'ignores it in favour of the CDX API' do
      expect(lookup).to eq cdx_snapshot
    end
  end

  context 'when the Availability API fails' do
    let(:availability_response) { { status: 504, body: 'Gateway Timeout' } }

    it 'falls back to the CDX API' do
      expect(lookup).to eq cdx_snapshot
    end
  end

  context 'when the URL has no good capture at all' do
    let(:cdx_response) { { body: '[]' } }

    it { is_expected.to be_nil }
  end

  context 'when the CDX API fails too' do
    let(:cdx_response) { { status: 503, body: 'unavailable' } }

    it { is_expected.to be_nil }
  end

  context 'when the CDX API answers with something other than JSON' do
    let(:cdx_response) { { body: '<html>oops</html>' } }

    it { is_expected.to be_nil }
  end

  context 'when the snapshot URL is too long to store' do
    let(:url) { "http://example.com/#{'a' * 1000}" }

    it { is_expected.to be_nil }
  end

  context 'with a blank URL' do
    let(:url) { '' }

    it 'returns nil without calling either API' do
      expect(lookup).to be_nil
      assert_not_requested(availability_request)
      assert_not_requested(cdx_request)
    end
  end
end
