# frozen_string_literal: true

class AddApprovedTaggingsCountToTags < ActiveRecord::Migration[8.0]
  def up
    add_column :tags, :approved_taggings_count, :integer, default: 0, null: false
    
    # Backfill the counter cache with correct values
    Tag.find_each do |tag|
      Tag.reset_counters(tag.id, :approved_taggings)
    end
  end

  def down
    remove_column :tags, :approved_taggings_count
  end
end
