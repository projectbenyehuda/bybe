# frozen_string_literal: true

# Migration to backpopulate in_volume and in_periodical fields in ManifestationsIndex
class BackpopulateManifestationCollectionFields < ActiveRecord::Migration[8.0]
  def up
    puts "Resetting ManifestationsIndex to populate in_volume and in_periodical fields..."
    puts "This may take a few minutes for large datasets."

    # Reset the index to ensure new fields are populated
    ManifestationsIndex.reset!

    puts "ManifestationsIndex reset complete!"
  end

  def down
    # No-op: down migration doesn't need to do anything
    # The fields will simply be ignored if code is rolled back
    puts "Rolling back - no action needed for index fields"
  end
end
