# frozen_string_literal: true

# This controller is used to generate user-friendly permanent URLs for files stored in ActiveStorage
# Initially it was created to manage files stored for Lexicon Entries, but we want to eventually use it for
# Manifestations as well.
# One limitation of this is that we assume all attachments attached to a given model are unique by filename.
class FilesController < ApplicationController
  # URL format: /files/:record_type/:record_id/:filename
  def download
    record_type = params.fetch(:record_type)
    record_id = params.fetch(:record_id)
    filename = [params.fetch(:filename), params[:format]].compact.join('.')

    # We use short codes for entry types in the URL for brevity
    if record_type == 'lex'
      record_type = LexEntry
      attachments_field = :attachments
    elsif record_type == 'text'
      record_type = Manifestation
      attachments_field = :images
    else
      render plain: "Invalid record type: '#{record_type}'", status: :bad_request
      return
    end

    entry = record_type.find_by(id: record_id)
    unless entry
      render plain: "Record not found: #{record_id}", status: :not_found
      return
    end

    attachment = entry.send(attachments_field).detect { |att| att.filename.to_s == filename }
    unless attachment
      render plain: "File not found: #{filename}", status: :not_found
      return
    end

    redirect_to rails_blob_url(attachment.blob, disposition: 'attachment')
  end
end
