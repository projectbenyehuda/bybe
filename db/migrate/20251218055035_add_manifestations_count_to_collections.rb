# frozen_string_literal: true

# Add manifestations_count counter cache to collections table
class AddManifestationsCountToCollections < ActiveRecord::Migration[8.0]
  def up
    add_column :collections, :manifestations_count, :integer, default: 0, null: false

    # Backfill existing collections with correct counts
    # We'll populate this after implementing the calculation method
    Collection.reset_column_information
    Collection.find_each do |collection|
      count = calculate_manifestations_count(collection)
      collection.update_column(:manifestations_count, count)
    end
  end

  private

  def calculate_manifestations_count(collection)
    count = 0
    stack = collection.collection_items.to_a

    while stack.any?
      current_item = stack.pop
      if current_item.item_type == 'Manifestation' && current_item.item.present?
        count += 1
      elsif current_item.item_type == 'Collection' && current_item.item.present?
        stack.concat(current_item.item.collection_items.to_a)
      end
    end

    count
  end

  def down
    remove_column :collections, :manifestations_count
  end
end
