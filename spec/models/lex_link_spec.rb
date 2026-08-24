# frozen_string_literal: true

require 'rails_helper'

describe LexLink do
  # A Wayback Machine replacement for a dead anchored URL frequently repeats the anchor, which
  # makes the URL unparseable and so instantly "broken" again. See by-p6e.
  describe 'trimming a duplicated anchor from the url' do
    subject(:url) { link.tap(&:validate).url }

    let(:link) { build(:lex_link, url: given_url) }

    context 'when the url repeats the same anchor' do
      let(:given_url) { 'https://web.archive.org/web/20200101/http://example.com/page#section#section' }

      it 'keeps a single anchor, leaving a parseable URL' do
        expect(url).to eq 'https://web.archive.org/web/20200101/http://example.com/page#section'
        expect(URI.parse(url)).to be_a URI::HTTPS
      end
    end

    context 'when the url has a single anchor' do
      let(:given_url) { 'http://example.com/page#section' }

      it { is_expected.to eq given_url }
    end

    context 'when the url has no anchor' do
      let(:given_url) { 'http://example.com/page' }

      it { is_expected.to eq given_url }
    end

    context 'when the repeated anchors differ' do
      let(:given_url) { 'http://example.com/page#one#two' }

      it { is_expected.to eq given_url }
    end
  end

  describe '#broken?' do
    subject { build(:lex_link, checked_at: checked_at, http_status: status).broken? }

    context 'when never checked (checked_at nil)' do
      let(:checked_at) { nil }
      let(:status) { nil }

      it { is_expected.to be false }
    end

    context 'when checked and unreachable (status nil)' do
      let(:checked_at) { Time.current }
      let(:status) { nil }

      it { is_expected.to be true }
    end

    context 'when checked and healthy (status 200)' do
      let(:checked_at) { Time.current }
      let(:status) { 200 }

      it { is_expected.to be false }
    end

    context 'when checked and 404' do
      let(:checked_at) { Time.current }
      let(:status) { 404 }

      it { is_expected.to be true }
    end

    context 'when checked and 500' do
      let(:checked_at) { Time.current }
      let(:status) { 500 }

      it { is_expected.to be true }
    end

    context 'when url is a local path (e.g. /files/...)' do
      subject { build(:lex_link, url: '/files/lex/7635/doc.pdf', checked_at: Time.current, http_status: nil).broken? }

      it { is_expected.to be false }
    end

    # A bot challenge (Cloudflare) tells us nothing about the link, so "we cannot tell" must not
    # be shown to editors as "broken". See by-9jz.
    context 'when the check hit a bot challenge (unverifiable)' do
      subject do
        build(:lex_link, checked_at: Time.current, http_status: 403, unverifiable: true).broken?
      end

      it { is_expected.to be false }
    end
  end
end
