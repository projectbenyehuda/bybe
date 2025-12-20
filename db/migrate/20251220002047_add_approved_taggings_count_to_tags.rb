# frozen_string_literal: true

class AddApprovedTaggingsCountToTags < ActiveRecord::Migration[8.0]
  def up
    add_column :tags, :approved_taggings_count, :integer, default: 0, null: false

    # Backfill the counter cache with correct values
    Tag.find_each do |tag|
      approved_count = tag.taggings.where(status: Tagging.statuses[:approved]).count
      tag.update_column(:approved_taggings_count, approved_count)
    end
  end

  def down
    remove_column :tags, :approved_taggings_count
  end
end
