# frozen_string_literal: true

module Lexicon
  # Service to migrate all images from html document to ActiveStorage.
  # It removes all processed image tags from html document
  class AttachImages < ApplicationService
    def call(html_doc, lex_entry)
      html_doc.css('img').each do |img|
        src = img['src']

        next if src.blank?

        # Handling for files shared between number of entries
        # They're stored in public/lex folder instead of ActiveStorage
        if src.start_with?('00000_files/')
          img['src'] = src.sub('00000_files/', '/lex/')
          next
        end

        # An image we could not migrate keeps a relative legacy path, which a browser resolves
        # against whatever page it is rendered on; send it back to the old site instead.
        migrated_path = MigrateAttachment.call(src, lex_entry).presence
        if migrated_path
          img['src'] = migrated_path
          set_dimensions(img, migrated_path)
        else
          img['src'] = ProcessLinks.absolutize(src)
        end
      end
    end

    private

    # Images hosted on our site get explicit width/height attributes (as in manifestations,
    # see insert_image.js), so the browser can reserve space for them and avoid layout shift (CLS).
    def set_dimensions(img, path)
      blob = blob_for_path(path)
      return if blob.nil?

      blob.analyze unless blob.analyzed?
      width = blob.metadata['width']
      height = blob.metadata['height']
      return if width.blank? || height.blank?

      img['width'] = width.to_s
      img['height'] = height.to_s
    end

    # Resolves a user-friendly download path (see DownloadLink#download_path) back to its blob
    def blob_for_path(path)
      params = Rails.application.routes.recognize_path(path.split('#').first)
      return nil unless params[:controller] == 'files'

      record_class = DownloadLink.record_class(params[:record_type])
      record_class&.find_by(id: params[:record_id])&.blob_by_filename(params[:filename])
    rescue ActionController::RoutingError
      nil
    end
  end
end
