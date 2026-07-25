# frozen_string_literal: true

# Concern with method to generate user-friendly download URLs for models with file attachments
# See FilesController for handling the download requests
module DownloadLink
  extend ActiveSupport::Concern

  # Convenient mapping of model class names to entry_type codes used in download URLs
  RECORD_TYPES = {
    'Manifestation' => { record_type: 'text', attachments_field: :images },
    'StaticPage' => { record_type: 'static', attachments_field: :images }
  }.freeze

  def download_path(filename)
    path = Rails.application.routes.url_helpers.file_download_path(
      record_type: file_record_type, record_id: id, filename: filename
    )

    # Unescape URI, so user can see Hebrew filenames
    URI::DEFAULT_PARSER.unescape(path)
  end

  def downloadable_attachments
    class_name = self.class.name
    type_data = RECORD_TYPES[class_name]
    raise "Unsupported class: #{class_name}" if type_data.nil?

    attachments_field = type_data[:attachments_field]
    send(attachments_field).attachments.includes(:blob)
  end

  def blob_by_filename(filename)
    attachment = downloadable_attachments.detect { |att| att.filename.to_s == filename }
    attachment&.blob
  end

  # Returns string record_type code for this entry, used in download URLs
  def file_record_type
    class_name = self.class.name
    type_data = RECORD_TYPES[class_name]
    raise "Unsupported class: #{class_name}" if type_data.nil?

    type_data[:record_type] if type_data.present?
  end

  # Converts a record_type code from the URL back to the corresponding model class name
  # Returns nil if no matching record_type is found
  def self.record_class(record_type)
    class_name = RECORD_TYPES.detect { |_class_name, data| data[:record_type] == record_type }&.first
    class_name&.constantize
  end

  # Key used to cache redirect URLs specified for given model instance
  def self.redirect_urls_cache_key(record_class, record_id)
    "redirect_urls_#{record_class}:#{record_id}"
  end

  # Method to clear cached redirect URLs for given model instance
  # Should be called every time we modify files attached to model
  def clear_redirect_urls_cache
    Rails.cache.delete(DownloadLink.redirect_urls_cache_key(self.class, id))
  end
end
