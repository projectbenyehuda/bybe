# frozen_string_literal: true

# Sidekiq job to update responsibility statements for manifestations in bulk
class UpdateManifestationResponsibilityStatementsJob
  include Sidekiq::Job

  def perform(manifestation_ids)
    return if manifestation_ids.blank?

    Manifestation.where(id: manifestation_ids).find_each do |manifestation|
      begin
        manifestation.recalc_responsibility_statement!
      rescue StandardError => e
        Rails.logger.error("Failed to recalculate responsibility_statement for Manifestation #{manifestation.id}: #{e.message}")
      end
    end
  end
end
