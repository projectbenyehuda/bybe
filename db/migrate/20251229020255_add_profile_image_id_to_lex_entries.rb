# frozen_string_literal: true

class AddProfileImageIdToLexEntries < ActiveRecord::Migration[8.0]
  def change
    add_column :lex_entries, :profile_image_id, :bigint, null: true
    add_foreign_key :lex_entries, :active_storage_attachments, column: :profile_image_id, on_delete: :nullify
    add_index :lex_entries, :profile_image_id
  end
end
