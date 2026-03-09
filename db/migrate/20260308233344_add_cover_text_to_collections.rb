# frozen_string_literal: true

class AddCoverTextToCollections < ActiveRecord::Migration[8.0]
  def change
    add_column :collections, :cover_text, :text
  end
end
