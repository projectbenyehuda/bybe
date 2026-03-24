# frozen_string_literal: true

# Adds a mediumtext column to cache textarea versions for ingestibles
class AddTextareCacheToIngestibles < ActiveRecord::Migration[8.0]
  def change
    add_column :ingestibles, :textarea_cache, :text, size: :medium
  end
end
