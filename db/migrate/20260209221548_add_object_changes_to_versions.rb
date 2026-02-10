# frozen_string_literal: true

class AddObjectChangesToVersions < ActiveRecord::Migration[8.0]
  def change
    add_column :versions, :object_changes, :json
  end
end
