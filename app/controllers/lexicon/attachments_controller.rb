# frozen_string_literal: true

module Lexicon
  # Controller to handle work with LexEntry attachments
  # This controller is mounted on lexicon/entries/:id/attachments path
  class AttachmentsController < ApplicationController
    include LockLexEntryConcern

    before_action do
      require_editor('edit_lexicon')
    end

    before_action :set_lex_entry
    before_action :try_to_lock_record

    helper_method :format_filesize

    # Returns content of LexEntry attachments panel
    def index
      # Normally loaded as a fragment (entry edit tab pane, verification workbench modal), but the
      # panel is also reachable by direct navigation, which needs the layout and its JS assets --
      # without them the remote form below degrades to a plain HTML submit.
      render layout: request.xhr? ? false : 'lexicon_backend'
    end

    def create
      file = params[:attachment]
      filename = file.original_filename.to_s

      if @lex_entry.attachments.any? { |att| att.blob.filename.to_s == filename }
        @error = t('.file_exists', filename: filename)
      else
        @lex_entry.attachments.attach(file)
      end

      respond_to do |format|
        format.js
        format.html do
          flash[:alert] = @error if @error.present?
          redirect_to lexicon_entry_attachments_path(@lex_entry)
        end
      end
    end

    def destroy
      @lex_entry.attachments.find_by(blob_id: params[:id]).purge
    end

    private

    def set_lex_entry
      @lex_entry = LexEntry.find(params[:entry_id])
    end

    def format_filesize(bytes_count)
      if bytes_count < 1024
        "#{bytes_count} B"
      elsif bytes_count < 1024 * 1024
        "#{(bytes_count / 1024.0).round} KB"
      else
        "#{(bytes_count / 1024.0 / 1024.0).round} MB"
      end
    end
  end
end
