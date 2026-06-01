# frozen_string_literal: true

class AddLockingFieldsToLexEntries < ActiveRecord::Migration[8.1]
  def change
    add_belongs_to :lex_entries,
                   :locked_by_user,
                   foreign_key: { to_table: :users},
                   index: true,
                   null: true,
                   type: :integer

    add_belongs_to :lex_entries,
                   :last_editor,
                   foreign_key: { to_table: :users},
                   index: true,
                   null: true,
                   type: :integer

    add_column :lex_entries, :locked_at, :timestamp, null: true
  end
end
