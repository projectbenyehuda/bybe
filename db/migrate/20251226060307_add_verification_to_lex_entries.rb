# frozen_string_literal: true

# Migration to add verification tracking to lexicon entries
class AddVerificationToLexEntries < ActiveRecord::Migration[8.0]
  def change
    # Add JSON column for verification progress tracking
    # Stores: verified_by, started_at, last_updated_at, checklist, overall_notes, ready_for_publish
    # MySQL doesn't allow default values for JSON columns, so we make it nullable
    add_column :lex_entries, :verification_progress, :json, null: true unless column_exists?(:lex_entries, :verification_progress)

    # Note: MySQL doesn't support direct indexing on JSON columns
    # If needed, we can add generated columns and index those instead
  end
end
