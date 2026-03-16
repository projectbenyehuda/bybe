# frozen_string_literal: true

class DropLexTexts < ActiveRecord::Migration[8.0]
  def change
    drop_table :lex_texts
  end
end
