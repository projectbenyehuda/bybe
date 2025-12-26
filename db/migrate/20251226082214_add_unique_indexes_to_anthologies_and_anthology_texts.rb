# frozen_string_literal: true

class AddUniqueIndexesToAnthologiesAndAnthologyTexts < ActiveRecord::Migration[8.0]
  def change
    add_index :anthologies, [:user_id, :title], unique: true
    add_index :anthology_texts, [:anthology_id, :manifestation_id], unique: true
  end
end
