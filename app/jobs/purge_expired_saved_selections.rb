# frozen_string_literal: true

# This job deletes expired SavedSelection objects
class PurgeExpiredSavedSelections < ApplicationJob
  def perform
    Rails.logger.info 'Purging expired saved selections'
    count = 0
    SavedSelection.where(delete_after: ...Time.zone.today).find_each do |saved_selection|
      count += 1 if saved_selection.destroy
    end
    Rails.logger.info "Purged #{count} expired saved selections"
  end
end
