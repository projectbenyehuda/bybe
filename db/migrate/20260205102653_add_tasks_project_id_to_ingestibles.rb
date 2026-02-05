# frozen_string_literal: true

class AddTasksProjectIdToIngestibles < ActiveRecord::Migration[8.0]
  def change
    add_column :ingestibles, :tasks_project_id, :integer
  end
end
