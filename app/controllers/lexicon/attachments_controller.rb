# frozen_string_literal: true

module Lexicon
  # Controller to handle work with LexEntry attachments
  # This controller is mounted on lexicon/entries/:id/attachments path
  class AttachmentsController < ApplicationController
    before_action :set_lex_entry

    helper_method :format_filesize

    # Returns content of LexEntry attachments panel
    def index
      render layout: false
    end

    def create
      @lex_entry.attachments.attach(params[:attachment])
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
