# frozen_string_literal: true

class RecalculateAllResponsibilityStatements < ActiveRecord::Migration[8.0]
  def up
    print "Recalculating responsibility statements for all manifestations... "
    Manifestation.find_each do |manifestation|
      begin
        manifestation.recalc_responsibility_statement!
      rescue StandardError => e
        Rails.logger.error("Failed to recalculate responsibility_statement for Manifestation #{manifestation.id}: #{e.message}")
      end
    end
    puts "done."
  end

  def down
    # No need to revert this data migration
  end
end
