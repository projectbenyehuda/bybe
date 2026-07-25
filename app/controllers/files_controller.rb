# frozen_string_literal: true

# This controller is used to generate user-friendly permanent URLs for files stored in ActiveStorage
# Initially it was created to manage files stored for Lexicon Entries, but we want to use it for
# Manifestations and StaticPages as well.
# One limitation of this is that we assume all attachments attached to a given model are unique by filename.
class FilesController < ApplicationController
  skip_before_action :set_paper_trail_whodunnit
  skip_before_action :set_base_user # Skip user initialization as it is a public URL

  # URL format: /files/:record_type/:record_id/:filename
  def download
    record_type = params.fetch(:record_type)
    record_id = params.fetch(:record_id)
    filename = params.fetch(:filename)

    # Resolve short code to class; if unknown, return Bad Request with message expected by tests
    record_class = DownloadLink.record_class(record_type)

    if record_class.nil?
      render plain: "Invalid record type: '#{record_type}'", status: :bad_request
      return
    end

    record_urls = cached_redirect_urls(record_class, record_id)

    redirect_url = record_urls[filename]
    if redirect_url.nil?
      render plain: "File not found: #{filename}", status: :not_found
      return
    end

    redirect_to redirect_url
  end

  private

  def cached_redirect_urls(record_class, record_id)
    cache_key = DownloadLink.redirect_urls_cache_key(record_class, record_id)
    Rails.cache.fetch(cache_key, expires_in: 2.hours, race_condition_ttl: 10.seconds) do
      record = record_class.find_by(id: record_id)

      result = {}
      record&.downloadable_attachments&.each do |attachment|
        blob = attachment.blob
        disposition = blob.image? ? 'inline' : 'attachment'
        result[attachment.filename.to_s] = rails_blob_url(blob, disposition: disposition)
      end
      result
    end
  end
end
