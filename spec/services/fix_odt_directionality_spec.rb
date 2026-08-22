# frozen_string_literal: true

require 'rails_helper'
require 'zip'

RSpec.describe FixOdtDirectionality do
  subject(:service) { described_class.new }

  let(:html) do
    <<~HTML
      <html><body>
        <h1>כותרת ראשית</h1>
        <p>פסקה רגילה בעברית.</p>
        <blockquote><p>ציטוט מוזח.</p></blockquote>
        <ul><li>פריט ראשון</li></ul>
      </body></html>
    HTML
  end

  let(:pandoc_odt) { PandocRuby.convert(html, from: :html, to: :odt) }

  # @return [Hash{String=>String}] entry name => contents
  def zip_entries(binary)
    entries = {}
    Zip::File.open_buffer(StringIO.new(binary.dup.force_encoding(Encoding::BINARY))) do |zip|
      zip.each { |entry| entries[entry.name] = entry.get_input_stream.read.force_encoding('UTF-8') if entry.file? }
    end
    entries
  end

  describe 'the bug being fixed' do
    it 'pandoc emits a left-to-right ODT even though we ask for dir=rtl' do
      styles = zip_entries(PandocRuby.convert(html, M: 'dir=rtl', from: :html, to: :odt))['styles.xml']

      expect(styles).to include('style:writing-mode="lr-tb"')
      expect(styles).not_to include('rl-tb')
    end
  end

  describe '#call' do
    let(:fixed) { service.call(pandoc_odt) }
    let(:fixed_entries) { zip_entries(fixed) }
    let(:default_paragraph_properties) do
      Nokogiri::XML(fixed_entries['styles.xml'])
              .at_xpath('//style:default-style[@style:family="paragraph"]/style:paragraph-properties',
                        described_class::NS)
    end

    it 'makes the default paragraph style right-to-left and right-aligned' do
      # LibreOffice maps fo:text-align start->left and end->right literally, so "end" is the right
      expect(default_paragraph_properties['style:writing-mode']).to eq('rl-tb')
      expect(default_paragraph_properties['fo:text-align']).to eq('end')
    end

    it 'leaves no left-to-right writing mode behind, page layout included' do
      styles = fixed_entries['styles.xml']

      expect(styles).not_to include('lr-tb')
      expect(styles).to include('style:writing-mode="rl-tb"')
    end

    it 'moves the footnote separator to the right' do
      expect(fixed_entries['styles.xml']).to include('style:adjustment="right"')
      expect(fixed_entries['styles.xml']).not_to include('style:adjustment="left"')
    end

    it 'returns a valid ODT package with mimetype stored first' do
      Zip::File.open_buffer(StringIO.new(fixed.dup.force_encoding(Encoding::BINARY))) do |zip|
        first = zip.entries.min_by(&:local_header_offset)
        expect(first.name).to eq('mimetype')
        expect(first.compression_method).to eq(Zip::Entry::STORED)
      end

      # ODF readers sniff the mimetype from a fixed offset (30-byte local header + the 8-byte
      # 'mimetype' name), which only works when it is the first entry and uncompressed
      expect(fixed[38, 39].force_encoding('UTF-8')).to eq('application/vnd.oasis.opendocument.text')
    end

    it 'preserves the rest of the package' do
      expect(fixed_entries.keys).to match_array(zip_entries(pandoc_odt).keys)
      expect(fixed_entries['content.xml']).to eq(zip_entries(pandoc_odt)['content.xml'])
      expect(fixed_entries['content.xml']).to include('כותרת ראשית')
    end

    it 'returns the input untouched when the archive has no styles.xml' do
      not_an_odt = Zip::OutputStream.write_buffer(StringIO.new(String.new)) do |zos|
        zos.put_next_entry('hello.txt')
        zos.write 'hello'
      end.string

      expect(service.call(not_an_odt)).to eq(not_an_odt)
    end
  end
end
