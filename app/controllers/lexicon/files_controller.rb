# frozen_string_literal: true

module Lexicon
  # Controller to manage Lexicon migration from static php files to Ben-Yehuda project
  class FilesController < ApplicationController
    before_action :set_lex_file, only: %i(migrate redo_migration)
    before_action do |c|
      c.require_editor('edit_lexicon')
    end
    layout 'lexicon_backend'

    def index
      @entrytype = params[:entrytype]
      @title = params[:title]
      @fname = params[:fname]
      @page = params[:page]
      @entry_statuses = params[:entry_statuses].presence || %w(raw migrating error draft)

      @lex_files = LexFile.joins(:lex_entry)

      @lex_files = @lex_files.where(entrytype: @entrytype) if @entrytype.present?
      @lex_files = @lex_files.where('lex_entries.title LIKE ?', "%#{@title}%") if @title.present?
      @lex_files = @lex_files.where('fname LIKE ?', "%#{@fname}%") if @fname.present?
      @lex_files = @lex_files.where(lex_entries: { status: @entry_statuses })

      @lex_files = @lex_files.preload(:lex_entry)
                             .order(:fname)
                             .page(@page)
    end

    def migrate
      lex_entry = @lex_file.lex_entry

      # From the stale page we can try to migrate file already being migrated or already migrated
      # In this case we simply re-render row
      return unless lex_entry.status_raw? || lex_entry.status_error?

      if lex_entry.status_error?
        lex_entry.reset_ingestion!
      end

      lex_entry.status_migrating!

      Lexicon::IngestFile.perform_async(@lex_file.id)
    end

    def redo_migration
      lex_entry = @lex_file.lex_entry
      return unless lex_entry.status_draft? || lex_entry.status_verifying? || lex_entry.status_escalated?

      lex_entry.reset_ingestion!
      @lex_file.reload
      @lex_file.status_classified! if @lex_file.status_ingested?
      lex_entry.status_migrating!
      Lexicon::IngestFile.perform_async(@lex_file.id)
    end

    private

    def set_lex_file
      @lex_file = LexFile.find(params[:id])
    end
  end
end
