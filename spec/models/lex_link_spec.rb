# frozen_string_literal: true

require 'rails_helper'

describe LexLink do
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
  end
end
