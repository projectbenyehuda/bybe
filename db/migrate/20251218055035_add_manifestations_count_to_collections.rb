# frozen_string_literal: true

# Add manifestations_count counter cache to collections table
class AddManifestationsCountToCollections < ActiveRecord::Migration[8.0]
  def up
    add_column :collections, :manifestations_count, :integer, default: 0, null: false

    # Backfill existing collections with correct counts
    Collection.reset_column_information

    total = Collection.count
    processed = 0
    start_time = Time.current

    say_with_time "Backfilling manifestations_count for #{total} collections" do
      Collection.find_each do |collection|
        count = calculate_manifestations_count(collection)
        collection.update_column(:manifestations_count, count)

        processed += 1
        if processed % 250 == 0
          elapsed = Time.current - start_time
          rate = processed / elapsed
          remaining = total - processed
          eta = remaining / rate

          say "  Processed #{processed}/#{total} collections (#{(processed.to_f / total * 100).round(1)}%) - " \
              "#{rate.round(1)}/sec - ETA: #{eta.round(0)}s", true
        end
      end

      processed # return count for say_with_time
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
