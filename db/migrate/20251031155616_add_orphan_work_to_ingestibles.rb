# frozen_string_literal: true

class AddOrphanWorkToIngestibles < ActiveRecord::Migration[8.0]
  def change
    add_column :ingestibles, :orphan_work, :boolean, default: false, null: false
  end
end
