# frozen_string_literal: true

class AddGenderToLexPeople < ActiveRecord::Migration[8.0]
  def change
    add_column :lex_people, :gender, :integer, default: 0
  end
end
