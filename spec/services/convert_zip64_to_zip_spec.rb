# frozen_string_literal: true

require 'rails_helper'
require 'zip'

RSpec.describe ConvertZip64ToZip do
  subject(:service) { described_class.new }

  let(:tempfile) { Tempfile.new(['test', '.zip'], encoding: 'ascii-8bit') }
  let(:file_path) { tempfile.path }

  after do
    tempfile.close
    tempfile.unlink
  end

  describe '#call' do
    context 'when file is a regular ZIP' do
      before do
        # Create a regular ZIP file
        Zip::File.open(file_path, create: true) do |zipfile|
          zipfile.get_output_stream('test.txt') { |f| f.write 'test content' }
        end
      end

      it 'returns the original file path' do
        result = described_class.call(file_path)
        expect(result).to eq(file_path)
      end
    end

    context 'when file is a ZIP64 archive' do
      before do
        # Create a ZIP64 DOCX file with zip64="true" in [Content_Types].xml
        Zip::File.open(file_path, create: true) do |zipfile|
          content_types_xml = <<~XML
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types" zip64="true">
              <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
              <Default Extension="xml" ContentType="application/xml"/>
            </Types>
          XML
          zipfile.get_output_stream('[Content_Types].xml') { |f| f.write content_types_xml }
        end

        # Mock the conversion process to return the same path (file is overwritten)
        allow_any_instance_of(described_class).to receive(:convert_to_regular_zip)
          .with(file_path)
          .and_return(file_path)
      end

      it 'calls convert_to_regular_zip' do
        expect_any_instance_of(described_class).to receive(:convert_to_regular_zip).with(file_path).and_return(file_path)
        described_class.call(file_path)
      end

      it 'returns the original file path (file is overwritten)' do
        result = described_class.call(file_path)
        expect(result).to eq(file_path)
      end
    end

    context 'when conversion fails' do
      before do
        # Create a ZIP64 DOCX file
        Zip::File.open(file_path, create: true) do |zipfile|
          content_types_xml = <<~XML
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types" zip64="true">
              <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            </Types>
          XML
          zipfile.get_output_stream('[Content_Types].xml') { |f| f.write content_types_xml }
        end

        # Mock conversion failure
        allow_any_instance_of(described_class).to receive(:convert_to_regular_zip)
          .and_call_original
        allow_any_instance_of(described_class).to receive(:system).and_return(false)
        allow(Rails.logger).to receive(:error)
      end

      it 'returns the original file path' do
        result = described_class.call(file_path)
        expect(result).to eq(file_path)
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Failed to convert ZIP64 to ZIP/)
        described_class.call(file_path)
      end
    end
  end

  describe '#zip64?' do
    context 'with ZIP64 DOCX (has zip64="true" in [Content_Types].xml)' do
      before do
        Zip::File.open(file_path, create: true) do |zipfile|
          # Create a [Content_Types].xml with zip64="true"
          content_types_xml = <<~XML
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types" zip64="true">
              <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
              <Default Extension="xml" ContentType="application/xml"/>
            </Types>
          XML
          zipfile.get_output_stream('[Content_Types].xml') { |f| f.write content_types_xml }
        end
      end

      it 'returns true' do
        expect(service.send(:zip64?, file_path)).to be true
      end
    end

    context 'with regular DOCX (no zip64 attribute in [Content_Types].xml)' do
      before do
        Zip::File.open(file_path, create: true) do |zipfile|
          # Create a [Content_Types].xml without zip64="true"
          content_types_xml = <<~XML
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
              <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
              <Default Extension="xml" ContentType="application/xml"/>
            </Types>
          XML
          zipfile.get_output_stream('[Content_Types].xml') { |f| f.write content_types_xml }
        end
      end

      it 'returns false' do
        expect(service.send(:zip64?, file_path)).to be false
      end
    end

    context 'with ZIP file missing [Content_Types].xml' do
      before do
        Zip::File.open(file_path, create: true) do |zipfile|
          zipfile.get_output_stream('test.txt') { |f| f.write 'test content' }
        end
      end

      it 'returns false' do
        expect(service.send(:zip64?, file_path)).to be false
      end
    end

    context 'with non-ZIP file' do
      before do
        File.write(file_path, 'not a zip file')
      end

      it 'returns false' do
        expect(service.send(:zip64?, file_path)).to be false
      end
    end

    context 'when file is too small' do
      before do
        File.write(file_path, 'tiny')
      end

      it 'returns false' do
        expect(service.send(:zip64?, file_path)).to be false
      end
    end

    context 'when file read fails' do
      let(:bad_file_path) { '/nonexistent/file.zip' }

      before do
        allow(Rails.logger).to receive(:warn)
      end

      it 'returns false' do
        expect(service.send(:zip64?, bad_file_path)).to be false
      end

      it 'logs a warning' do
        expect(Rails.logger).to receive(:warn).with(/Error checking for ZIP64/)
        service.send(:zip64?, bad_file_path)
      end
    end
  end
end
