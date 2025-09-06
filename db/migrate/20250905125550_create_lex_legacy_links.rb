# frozen_string_literal: true

class CreateLexLegacyLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :lex_legacy_links do |t|
      t.string :old_path, null: false
      t.string :new_path, null: false
      t.references :lex_entry, null: false, foreign_key: true, index: true
    end

    add_index :lex_legacy_links, [:old_path], unique: true
  end
end
