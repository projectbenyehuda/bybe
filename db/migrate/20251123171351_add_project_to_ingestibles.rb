# frozen_string_literal: true

class AddProjectToIngestibles < ActiveRecord::Migration[8.0]
  def change
    add_reference :ingestibles, :project, foreign_key: true, null: true
  end
end
