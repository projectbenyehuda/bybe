# frozen_string_literal: true

class AddIndexesToTaggings < ActiveRecord::Migration[8.0]
  def change
    # Add index on status alone - used in many queries filtering by status
    add_index :taggings, :status, name: 'index_taggings_on_status'

    # Add composite index for tag_id + status - for queries like tag.taggings.pending
    add_index :taggings, [:tag_id, :status], name: 'index_taggings_on_tag_id_and_status'

    # Add composite index for suggested_by + status + created_at
    # Used in User#recent_tags_used which is called when loading tagging popup
    add_index :taggings, [:suggested_by, :status, :created_at],
              name: 'index_taggings_on_suggested_by_status_created_at'

    # Add composite index for status + created_at - for pending taggings ordered by time
    add_index :taggings, [:status, :created_at], name: 'index_taggings_on_status_and_created_at'

    # Add composite index for approved_by + status - for moderator statistics
    add_index :taggings, [:approved_by, :status], name: 'index_taggings_on_approved_by_and_status'

    # Add composite index for tag_id + taggable - for duplicate checking during merges
    add_index :taggings, [:tag_id, :taggable_id, :taggable_type],
              name: 'index_taggings_on_tag_and_taggable'
  end
end
