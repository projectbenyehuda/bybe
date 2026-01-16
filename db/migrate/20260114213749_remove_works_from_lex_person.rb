# frozen_string_literal: true

class RemoveWorksFromLexPerson < ActiveRecord::Migration[8.0]
  def change
    remove_column :lex_people, :works, :text
  end
end
