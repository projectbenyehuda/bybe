# frozen_string_literal: true

class DropAboutFromLexPeople < ActiveRecord::Migration[8.0]
  def change
    remove_column :lex_people, :about, type: :text
  end
end
