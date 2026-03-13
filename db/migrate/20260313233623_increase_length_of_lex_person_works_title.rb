# frozen_string_literal: true

class IncreaseLengthOfLexPersonWorksTitle < ActiveRecord::Migration[8.0]
  def change
    change_column :lex_person_works, :title, :string, limit: 500, null: false
  end
end
