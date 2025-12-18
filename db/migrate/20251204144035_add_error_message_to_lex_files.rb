# frozen_string_literal: true

class AddErrorMessageToLexFiles < ActiveRecord::Migration[8.0]
  def change
    add_column :lex_files, :error_message, :text, if_not_exists: true
  end
end
