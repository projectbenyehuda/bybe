# frozen_string_literal: true

# Persists the size of the legacy source file, so /lex/files can filter on it in SQL instead of
# stat'ing every file on each request. Existing rows are filled by `rake backfill_lex_file_sizes`.
class AddFileSizeBytesToLexFiles < ActiveRecord::Migration[8.0]
  def change
    add_column :lex_files, :file_size_bytes, :bigint
  end
end
