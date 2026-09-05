# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Converters::EpubToMobi do
  describe '#call' do
    let(:epub_filename) { '/tmp/book.epub' }
    let(:mobi_filename) { '/tmp/book.mobi' }
    let(:service) { described_class.new }

    it 'converts the EPUB file and returns the MOBI filename' do
      allow(service).to receive(:system)
        .with('ebook-convert', epub_filename, mobi_filename)
        .and_return(true)

      expect(service.call(epub_filename)).to eq(mobi_filename)
      expect(service).to have_received(:system).with('ebook-convert', epub_filename, mobi_filename)
    end

    it 'raises an error when conversion fails' do
      allow(service).to receive(:system)
        .with('ebook-convert', epub_filename, mobi_filename)
        .and_return(false)

      expect { service.call(epub_filename) }
        .to raise_error(RuntimeError, "ebook-convert failed: #{epub_filename} -> #{mobi_filename}")
      expect(service).to have_received(:system).with('ebook-convert', epub_filename, mobi_filename)
    end
  end
end
