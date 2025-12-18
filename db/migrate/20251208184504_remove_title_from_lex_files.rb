# frozen_string_literal: true

class RemoveTitleFromLexFiles < ActiveRecord::Migration[8.0]
  def change
    remove_column :lex_files, :title, :string, if_exists: true
  end
end
