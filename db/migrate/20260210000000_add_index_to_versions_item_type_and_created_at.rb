# frozen_string_literal: true

class AddIndexToVersionsItemTypeAndCreatedAt < ActiveRecord::Migration[8.0]
  def change
    add_index :versions, %i[item_type created_at], name: 'index_versions_on_item_type_and_created_at'
  end
end
