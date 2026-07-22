# frozen_string_literal: true

# Job to expire crowdsourcing tasks
class ExpireCrowdsourcingTasksJob < ApplicationJob
  def perform
    Rails.logger.info('Expiring assigned crowdsourcing tasks')
    ListItem.where(listkey: CrowdController::LISTKEY_POPULATE_EDITION).where(updated_at: ...2.hours.ago).destroy_all
  end
end
