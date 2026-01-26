# frozen_string_literal: true

# Concern with method to generate user-friendly download URLs for models with file attachments
# See FilesController for handling the download requests
module DownloadLink
  extend ActiveSupport::Concern

  def download_path(filename)
    Rails.application.routes.url_helpers.file_download_path(
      record_type: file_entry_type, record_id: id, filename: filename
    )
  end

  private

  def file_entry_type
    case self.class.name
    when 'LexEntry'
      'lex'
    when 'Manifestation'
      'text'
    else
      raise "Unsupported entry type: #{self.class.name}"
    end
  end
end
