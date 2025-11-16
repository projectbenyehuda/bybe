# frozen_string_literal: true

class AddIndexByTitleToPublication < ActiveRecord::Migration[8.0]
  def change
    add_index :publications, :title, length: 200
  end
end
