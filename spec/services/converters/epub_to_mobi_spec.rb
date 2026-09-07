# frozen_string_literal: true

require 'rails_helper'

describe Converters::EpubToMobi do
  describe '.call' do
    subject(:result) { described_class.call(epub_filename) }

    context 'when file exists and valid' do
      let(:epub_filename) { Rails.root.join('spec/fixtures/files/converters/sample.epub').to_s }

      it 'creates a mobi file with the same name' do
        expect(result).to eq(Rails.root.join('spec/fixtures/files/converters/sample.mobi').to_s)
        expect(File.exist?(result)).to be true
      end

      after do
        File.delete(epub_filename.gsub(/epub$/, 'mobi'))
      end
    end

    context 'when source file does not exist' do
      let(:epub_filename) { 'missing.epub' }

      it 'raises an exception' do
        expect { result }.to raise_error(RuntimeError, 'ebook-convert failed: missing.epub -> missing.mobi')
      end
    end

    context 'when source file is invalid' do
      let(:epub_filename) { Rails.root.join('spec/fixtures/files/converters/broken.epub').to_s }

      it 'raises an exception' do
        expect { result }.to raise_error(RuntimeError, /ebook-convert failed/)
      end
    end
  end
end