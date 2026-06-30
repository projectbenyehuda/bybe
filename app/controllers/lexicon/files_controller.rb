# frozen_string_literal: true

module Lexicon
  # Controller to manage Lexicon migration from static php files to Ben-Yehuda project
  class FilesController < ApplicationController
    include LockRecordConcern

    before_action :set_lex_file, only: %i(migrate redo_migration)
    before_action do |c|
      c.require_editor('edit_lexicon')
    end
    # Starting (or redoing) a migration locks the entry to the current editor, and refuses
    # if another editor already holds the lock.
    before_action :try_to_lock_record, only: %i(migrate redo_migration)
    layout 'lexicon_backend'

    SORTABLE_COLUMNS = %w(fname migration_item_count).freeze
    SORT_DIRECTIONS = %w(asc desc).freeze

    def index
      @entrytype = params[:entrytype]
      @title = params[:title]
      @fname = params[:fname]
      @page = params[:page]
      @entry_statuses = params[:entry_statuses].presence || %w(raw migrating error draft verifying)
      @sort = params[:sort].presence_in(SORTABLE_COLUMNS) || 'fname'
      @direction = params[:direction].presence_in(SORT_DIRECTIONS) || 'asc'

      scope = LexFile.joins(:lex_entry)

      scope = scope.where(entrytype: @entrytype) if @entrytype.present?
      scope = scope.where('lex_entries.title LIKE ?', "%#{@title}%") if @title.present?
      scope = scope.where('fname LIKE ?', "%#{@fname}%") if @fname.present?
      scope = scope.where(lex_entries: { status: @entry_statuses })

      sort_clause = if @sort == 'migration_item_count'
                      "lex_entries.migration_item_count #{@direction}, lex_files.id ASC"
                    else
                      "#{@sort} #{@direction}, lex_files.id ASC"
                    end

      # Files whose entry is currently locked are surfaced in their own sections (mine vs. others')
      # and excluded from the main paginated list to avoid showing the same file twice.
      locked_files = scope.where('lex_entries.locked_at > ?', LexEntry::LOCK_TIMEOUT_IN_SECONDS.seconds.ago)
      @my_locked_files = locked_files.where(lex_entries: { locked_by_user_id: current_user.id })
                                     .preload(:lex_entry).order(:fname)
      @locked_by_others_files = locked_files.where.not(lex_entries: { locked_by_user_id: current_user.id })
                                            .preload(:lex_entry).order(:fname)

      @lex_files = scope.where.not(id: locked_files.select('lex_files.id'))
                        .preload(:lex_entry)
                        .order(Arel.sql(sort_clause))
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

      Lexicon::IngestFile.perform_later(@lex_file.id)
      # Signals the JS response to send the editor to the verification queue (see migrate.js.erb).
      @migration_launched = true
    end

    def redo_migration
      lex_entry = @lex_file.lex_entry
      return unless lex_entry.redo_migration_eligible?

      lex_entry.reset_ingestion!
      @lex_file.reload
      @lex_file.status_classified! if @lex_file.status_ingested?
      lex_entry.status_migrating!
      Lexicon::IngestFile.perform_later(@lex_file.id)
      @migration_launched = true
    end

    private

    def set_lex_file
      @lex_file = LexFile.find(params[:id])
    end

    # LockRecordConcern hooks: the lockable record is the file's entry, and a blocked
    # request returns to the files queue.
    def record_to_lock
      @lex_file.lex_entry
    end

    def redirect_if_locked_path
      lexicon_files_path
    end
  end
end
