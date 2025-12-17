# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FixDocxInheritedFormatting do
  describe '#call' do
    let(:input_file) { Rails.root.join('spec/fixtures/docx/inherited_formatting_test.docx') }
    let(:docx_binary) { File.binread(input_file) }
    let(:service) { described_class.new }

    it 'fixes inherited formatting in DOCX files' do
      fixed_binary = service.call(docx_binary)

      expect(fixed_binary).to be_present
      expect(fixed_binary).to be_a(String)
      expect(fixed_binary.encoding).to eq(Encoding::ASCII_8BIT)

      # Verify it's a valid ZIP file (DOCX is a ZIP)
      Tempfile.create(['test_output_', '.docx'], encoding: 'ascii-8bit') do |tmpfile|
        tmpfile.write(fixed_binary)
        tmpfile.flush

        expect do
          Zip::File.open(tmpfile.path) { |zip| zip.entries }
        end.not_to raise_error
      end
    end

    it 'preserves DOCX structure' do
      fixed_binary = service.call(docx_binary)

      Tempfile.create(['test_output_', '.docx'], encoding: 'ascii-8bit') do |tmpfile|
        tmpfile.write(fixed_binary)
        tmpfile.flush

        # Verify key files exist in the ZIP
        Zip::File.open(tmpfile.path) do |zip|
          expect(zip.find_entry('word/document.xml')).to be_present
          expect(zip.find_entry('word/styles.xml')).to be_present
          expect(zip.find_entry('[Content_Types].xml')).to be_present
        end
      end
    end

    context 'with bold text in paragraph styles' do
      it 'explicitly applies inherited bold formatting to runs' do
        fixed_binary = service.call(docx_binary)

        # Verify the fixed file can be converted to markdown with bold preserved
        Tempfile.create(['test_output_', '.docx'], encoding: 'ascii-8bit') do |tmpfile|
          tmpfile.write(fixed_binary)
          tmpfile.flush

          # Convert to markdown and check for bold markers
          markdown = `pandoc -f docx -t markdown_mmd #{tmpfile.path} 2>&1`

          # Check that יומן is now bolded in the output
          expect(markdown).to include('**יומן**')
        end
      end
    end

    it 'handles documents without inherited formatting gracefully' do
      # Should not raise errors even if there's nothing to fix
      expect { service.call(docx_binary) }.not_to raise_error
    end
  end
end
