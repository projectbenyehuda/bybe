# frozen_string_literal: true

class AddIndexToManifestationsTitle < ActiveRecord::Migration[8.0]
  def change
    add_index :manifestations, :title
  end
end
