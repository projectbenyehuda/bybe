# frozen_string_literal: true

class IncreaseLengthOfLexPersonBio < ActiveRecord::Migration[8.1]
  def change
    change_column :lex_people, :bio, :text, limit: 200000
  end
end
