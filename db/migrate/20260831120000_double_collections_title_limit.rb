# frozen_string_literal: true

# varchar(1024) has proven too short for some collection titles. Double it to 2048.
class DoubleCollectionsTitleLimit < ActiveRecord::Migration[8.0]
  def up
    change_column :collections, :title, :string, limit: 2048
  end

  def down
    change_column :collections, :title, :string, limit: 1024
  end
end
