# frozen_string_literal: true

class AddTasksProjectIdToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :tasks_project_id, :integer
  end
end
