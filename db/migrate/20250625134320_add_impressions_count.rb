# frozen_string_literal: true

class AddImpressionsCount < ActiveRecord::Migration[6.1]
  def change
    add_column :anthologies, :impressions_count, :integer, default: 0, if_not_exists: true
    add_column :collections, :impressions_count, :integer, default: 0, if_not_exists: true
  end
end
