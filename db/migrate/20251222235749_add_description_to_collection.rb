# frozen_string_literal: true

class AddDescriptionToCollection < ActiveRecord::Migration[8.0]
  def change
    add_column :collections, :description, :text
  end
end
