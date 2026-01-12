# frozen_string_literal: true

module Lexicon
  # Controller to manage Lexicon migration from static php files to Ben-Yehuda project
  class FilesController < ApplicationController
    before_action :set_lex_file, only: [:migrate]
    before_action do |c|
      c.require_editor('edit_lexicon')
    end
    layout 'lexicon_backend'

    def index
      @lex_files = LexFile.all
      @entrytype = params[:entrytype]
      @title = params[:title]

      if @entrytype.present?
        @lex_files = @lex_files.where(entrytype: @entrytype)
      end

      if @title.present?
        @lex_files = @lex_files.joins(:lex_entry)
                               .where('lex_entries.title LIKE ?', "%#{@title}%")
      end

      @lex_files = @lex_files.includes(:lex_entry)
                             .order(:fname)
                             .page(params[:page])
    end

    def migrate
      if @lex_file.error_message.present?
        @lex_file.update!(error_message: nil)
      end

      lex_entry = @lex_file.lex_entry
      lex_item = lex_entry.lex_item
      lex_entry.lex_item = nil
      lex_entry.status_migrating!

      # Cleaning up any existing LexItem before re-ingesting
      lex_item.destroy! if lex_item.present?
      Lexicon::IngestFile.perform_async(@lex_file.id)

      redirect_to lexicon_files_path, notice: t('.success')
    end

    private

    def set_lex_file
      @lex_file = LexFile.find(params[:id])
    end
  end
end
