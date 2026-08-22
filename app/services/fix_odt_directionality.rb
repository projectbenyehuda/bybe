# frozen_string_literal: true

require 'zip'
require 'nokogiri'
require 'stringio'

# Pandoc's ODT writer ignores the `dir=rtl` metadata that makes its DOCX output right-to-left
# (the DOCX writer emits <w:bidi/> and <w:rtl/>; the ODT writer emits nothing), so ODT downloads
# of our Hebrew texts come out left-aligned. This service post-processes the ODT pandoc produced,
# rewriting styles.xml so the document defaults to RTL.
#
# Note on `fo:text-align="end"`: per ODF, start/end are relative to the writing mode, so "end" in
# an rl-tb paragraph ought to resolve to the physical left. LibreOffice, however, maps start->left
# and end->right literally, and writes `fo:text-align="end"` alongside `style:writing-mode="rl-tb"`
# for its own RTL paragraphs. We emit what LibreOffice emits.
#
# Example:
#   rtl_binary = FixOdtDirectionality.call(odt_binary)
class FixOdtDirectionality < ApplicationService
  NS = {
    'office' => 'urn:oasis:names:tc:opendocument:xmlns:office:1.0',
    'style' => 'urn:oasis:names:tc:opendocument:xmlns:style:1.0',
    'fo' => 'urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0'
  }.freeze

  # @param odt_binary [String] ODT file as a binary string
  # @return [String] ODT file as a binary string, defaulting to right-to-left
  def call(odt_binary)
    entries = unzip(odt_binary)
    return odt_binary if entries['styles.xml'].nil?

    entries['styles.xml'] = rtl_styles(entries['styles.xml'])
    rezip(entries)
  end

  private

  # @return [Hash{String=>String}] entry name => contents, in the archive's original order
  def unzip(odt_binary)
    entries = {}
    Zip::File.open_buffer(StringIO.new(odt_binary.dup.force_encoding(Encoding::BINARY))) do |zip|
      zip.each { |entry| entries[entry.name] = entry.get_input_stream.read if entry.file? }
    end
    entries
  end

  def rezip(entries)
    buffer = Zip::OutputStream.write_buffer(StringIO.new(''.b)) do |zos|
      # ODF requires 'mimetype' to be the archive's first entry, stored uncompressed
      if entries.key?('mimetype')
        zos.put_next_entry('mimetype', nil, nil, Zip::Entry::STORED)
        zos.write entries['mimetype']
      end
      entries.each do |name, content|
        next if name == 'mimetype'

        zos.put_next_entry(name)
        zos.write content
      end
    end
    buffer.string.force_encoding(Encoding::BINARY)
  end

  def rtl_styles(styles_xml)
    doc = Nokogiri::XML(styles_xml)

    # Flip every declared writing mode, the page layout's included
    doc.xpath('//*[@style:writing-mode]', NS).each { |node| node['style:writing-mode'] = 'rl-tb' }

    # Pandoc's default paragraph style says writing-mode="page", which LibreOffice does not resolve
    # to the page layout's direction, so state it outright along with the alignment.
    props = doc.at_xpath('//style:default-style[@style:family="paragraph"]/style:paragraph-properties', NS)
    if props.present?
      props['style:writing-mode'] = 'rl-tb'
      props['fo:text-align'] = 'end'
    end

    # The footnote separator line hangs off the start of the line, which in RTL is the right
    doc.xpath('//style:footnote-sep[@style:adjustment="left"]', NS).each do |sep|
      sep['style:adjustment'] = 'right'
    end

    doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
  end
end
