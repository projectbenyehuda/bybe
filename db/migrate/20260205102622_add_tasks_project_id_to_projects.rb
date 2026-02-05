# frozen_string_literal: true

class AddTasksProjectIdToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :tasks_project_id, :integer
    add_index :projects, :tasks_project_id, unique: true
  end
end
