# frozen_string_literal: true

require 'zip'
require 'tmpdir'

# Service to convert ZIP64 archives to regular ZIP format
# This is necessary because some processing tools (e.g., Pandoc) don't support ZIP64
class ConvertZip64ToZip < ApplicationService
  # @param file_path [String] Path to the potentially ZIP64 file
  # @return [String] Path to the converted file (or original if no conversion needed)
  def call(file_path)
    return file_path unless zip64?(file_path)

    Rails.logger.info("ZIP64 archive detected, converting to regular ZIP: #{file_path}")
    convert_to_regular_zip(file_path)
  end

  private

  # Check if a file is a ZIP64 archive
  # For DOCX files, we check the [Content_Types].xml file for zip64="true" attribute
  def zip64?(file_path)
    Zip::File.open(file_path) do |zip_file|
      # Look for [Content_Types].xml entry
      content_types_entry = zip_file.find_entry('[Content_Types].xml')
      return false unless content_types_entry

      # Read the XML content
      xml_content = content_types_entry.get_input_stream.read

      # Check for zip64="true" attribute
      return xml_content.include?('zip64="true"')
    end
  rescue StandardError => e
    Rails.logger.warn("Error checking for ZIP64: #{e.message}")
    false
  end

  # Convert ZIP64 archive to regular ZIP
  # Overwrites the original file with the converted version
  def convert_to_regular_zip(file_path)
    # Create a temporary directory for extraction
    Dir.mktmpdir do |extract_dir|
      # Extract using system unzip which supports ZIP64
      unless system('unzip', '-q', file_path, '-d', extract_dir)
        raise "Failed to extract ZIP64 archive: #{file_path}"
      end

      # Create a new temporary file for the repacked ZIP
      temp_output = Tempfile.new(['converted_', File.extname(file_path)], encoding: 'ascii-8bit')
      temp_output_path = temp_output.path
      temp_output.close
      temp_output.unlink # Delete it so we can create the ZIP file at this path

      # Repack as regular ZIP using rubyzip
      Zip::File.open(temp_output_path, create: true) do |zipfile|
        # Add all extracted files to the new ZIP
        Dir.glob("#{extract_dir}/**/*", File::FNM_DOTMATCH).each do |file|
          next if File.directory?(file)
          next if File.basename(file) == '.' || File.basename(file) == '..'

          # Calculate the relative path within the ZIP
          zip_entry_path = file.sub("#{extract_dir}/", '')

          # Add the file to the ZIP
          zipfile.add(zip_entry_path, file)
        end
      end

      # Replace the original file with the converted version
      FileUtils.mv(temp_output_path, file_path)

      Rails.logger.info("ZIP64 converted to regular ZIP, overwrote: #{file_path}")
      file_path
    end
  rescue StandardError => e
    Rails.logger.error("Failed to convert ZIP64 to ZIP: #{e.message}")
    # Return original file path if conversion fails
    file_path
  end
end
