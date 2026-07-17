# frozen_string_literal: true

class AddKwicColumns < ActiveRecord::Migration[8.1]
  def change
    add_column :collections, :kwic_generation_started_at, :timestamp
    add_column :authorities, :kwic_generation_started_at, :timestamp
  end
end
