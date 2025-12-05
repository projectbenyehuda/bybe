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
  # ZIP64 format uses specific signatures that we can detect
  def zip64?(file_path)
    File.binread(file_path).tap do |content|
      # ZIP64 end of central directory signature bytes: 50 4B 06 06
      # ZIP64 end of central directory locator signature bytes: 50 4B 06 07
      # Using byte arrays for more reliable detection
      zip64_eocd_sig = [0x50, 0x4B, 0x06, 0x06].pack('C*')
      zip64_eocd_locator_sig = [0x50, 0x4B, 0x06, 0x07].pack('C*')

      # Check for either signature in the file
      return true if content.include?(zip64_eocd_sig) || content.include?(zip64_eocd_locator_sig)
    end

    false
  rescue StandardError => e
    Rails.logger.warn("Error checking for ZIP64: #{e.message}")
    false
  end

  # Convert ZIP64 archive to regular ZIP
  def convert_to_regular_zip(file_path)
    # Create a temporary directory for extraction
    Dir.mktmpdir do |extract_dir|
      # Extract using system unzip which supports ZIP64
      unless system('unzip', '-q', file_path, '-d', extract_dir)
        raise "Failed to extract ZIP64 archive: #{file_path}"
      end

      # Create a new temporary file for the repacked ZIP
      output_file = Tempfile.new(['converted_', File.extname(file_path)], encoding: 'ascii-8bit')
      output_file.close

      # Repack as regular ZIP using rubyzip
      Zip::File.open(output_file.path, create: true) do |zipfile|
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

      Rails.logger.info("ZIP64 converted to regular ZIP: #{output_file.path}")
      output_file.path
    end
  rescue StandardError => e
    Rails.logger.error("Failed to convert ZIP64 to ZIP: #{e.message}")
    # Return original file path if conversion fails
    file_path
  end
end
