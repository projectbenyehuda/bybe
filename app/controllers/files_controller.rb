# frozen_string_literal: true

# This controller is used to generate user-friendly permanent URLs for files stored in ActiveStorage
# Initially it was created to manage files stored for Lexicon Entries, but we want to use it for
# Manifestations and StaticPages as well.
# One limitation of this is that we assume all attachments attached to a given model are unique by filename.
class FilesController < ApplicationController
  # URL format: /files/:record_type/:record_id/:filename
  def download
    record_type = params.fetch(:record_type)
    record_id = params.fetch(:record_id)
    filename = [params.fetch(:filename), params[:format]].compact.join('.')

    # Resolve short code to class; if unknown, return Bad Request with message expected by tests
    record_class = DownloadLink::record_class(record_type)

    if record_class.nil?
      render plain: "Invalid record type: '#{record_type}'", status: :bad_request
      return
    end

    record = record_class.find_by(id: record_id)
    if record.nil?
      render plain: "Record not found: #{record_id}", status: :not_found
      return
    end

    blob = record.blob_by_filename(filename)
    unless blob
      render plain: "File not found: #{filename}", status: :not_found
      return
    end

    redirect_to rails_blob_url(blob, disposition: 'attachment')
  end
end
