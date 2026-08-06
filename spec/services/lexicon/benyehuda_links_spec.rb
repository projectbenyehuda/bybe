# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::BenyehudaLinks do
  describe '.authority_for' do
    subject(:authority) { described_class.authority_for(url) }

    let(:expected_authority) { create(:authority) }

    context 'when the URL is a benyehuda.org numeric author link' do
      let(:url) { "https://benyehuda.org/author/#{expected_authority.id}" }

      it { is_expected.to eq(expected_authority) }
    end

    context 'when the URL uses the www host and a trailing slash' do
      let(:url) { "https://www.benyehuda.org/author/#{expected_authority.id}/" }

      it { is_expected.to eq(expected_authority) }
    end

    context 'when the URL is a benyehuda.org slug matched by HtmlDir' do
      let(:url) { 'https://benyehuda.org/shats/index' }

      before { HtmlDir.create!(path: 'shats', person: expected_authority.person, author: 'Shats') }

      it { is_expected.to eq(expected_authority) }
    end

    context 'when the numeric ID matches no Authority' do
      let(:url) { 'https://benyehuda.org/author/999999' }

      it { is_expected.to be_nil }
    end

    context 'when the slug matches no HtmlDir' do
      let(:url) { 'https://benyehuda.org/nonexistent_slug' }

      it { is_expected.to be_nil }
    end

    context 'when the host is not benyehuda.org' do
      let(:url) { "https://example.com/author/#{expected_authority.id}" }

      it { is_expected.to be_nil }
    end

    context 'when the host merely starts with benyehuda.org' do
      let(:url) { "https://benyehuda.org.il/author/#{expected_authority.id}" }

      it { is_expected.to be_nil }
    end

    context 'when the host is a lookalike subdomain of another domain' do
      let(:url) { "https://benyehuda.org.example.com/author/#{expected_authority.id}" }

      it { is_expected.to be_nil }
    end

    context 'when benyehuda.org appears as userinfo rather than the host' do
      let(:url) { "https://benyehuda.org@example.com/author/#{expected_authority.id}" }

      it { is_expected.to be_nil }
    end

    context 'when benyehuda.org appears only in the path of another host' do
      let(:url) { "https://example.com/benyehuda.org/author/#{expected_authority.id}" }

      it { is_expected.to be_nil }
    end

    context 'when the scheme is not http(s)' do
      let(:url) { "ftp://benyehuda.org/author/#{expected_authority.id}" }

      it { is_expected.to be_nil }
    end

    context 'when the URL has no path' do
      let(:url) { 'https://benyehuda.org' }

      it { is_expected.to be_nil }
    end

    context 'when the URL is unparseable' do
      let(:url) { 'https://benyehuda.org/author/1 2' }

      it { is_expected.to be_nil }
    end

    context 'when the URL is nil' do
      let(:url) { nil }

      it { is_expected.to be_nil }
    end
  end
end
