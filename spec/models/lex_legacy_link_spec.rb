# frozen_string_literal: true

require 'rails_helper'

describe LexLegacyLink do
  describe 'old_path normalization' do
    subject do
      link.valid?
      link.old_path
    end

    let(:link) { build(:lex_legacy_link, old_path: old_path) }

    context 'when path uses different cases' do
      let(:old_path) { 'files/SomeFile.pdf' }

      it { is_expected.to eq 'files/somefile.pdf' }
    end

    context 'when path starts with /' do
      let(:old_path) { '/files/file.JPG' }

      it { is_expected.to eq 'files/file.jpg' }
    end

    context 'when path contains https protocol and domain name' do
      let(:old_path) { "https://#{Lexicon::OLD_LEXICON_PATH}/files/1.jpg" }

      it { is_expected.to eq 'files/1.jpg' }
    end

    context 'when path contains http protocol and domain name' do
      let(:old_path) { "http://#{Lexicon::OLD_LEXICON_PATH}/files/1.jpg" }

      it { is_expected.to eq 'files/1.jpg' }
    end
  end

  describe '.find_existing' do
    subject { described_class.find_existing(old_path) }

    let(:lex_entry) { create(:lex_entry, :person) }
    let!(:link) { create(:lex_legacy_link, old_path: 'file/1.jpg', lex_entry: lex_entry) }

    context 'when non-normalized but matching path is provided' do
      let(:old_path) { '/file/1.JPG' }

      it { is_expected.to eq link }
    end

    context 'when matching path is provided' do
      let(:old_path) { 'file/1.jpg' }

      it { is_expected.to eq link }
    end

    context 'when non-matching path is provided' do
      let(:old_path) { 'file/2.jpg' }

      it { is_expected.to be_nil }
    end
  end
end
