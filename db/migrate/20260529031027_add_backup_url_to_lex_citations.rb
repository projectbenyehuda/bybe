# frozen_string_literal: true

# Migration to add backup_url column to lex_citations for storing asterisk-linked file URLs
class AddBackupUrlToLexCitations < ActiveRecord::Migration[8.1]
  def change
    add_column :lex_citations, :backup_url, :string, limit: 1024
  end
end
