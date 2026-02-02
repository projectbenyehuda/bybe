# frozen_string_literal: true

# Reset cached_credits for all Collections to ensure the invalidation fix in
# IngestiblesController is properly reflected in production data
class ResetCachedCreditsOnCollections < ActiveRecord::Migration[8.0]
  def up
    # Update all collections to have nil cached_credits
    # This will force recalculation on next fetch_credits call
    Collection.update_all(cached_credits: nil)
  end

  def down
    # No-op: cached_credits will be regenerated on demand via fetch_credits
    # We cannot restore the old cached values
  end
end
