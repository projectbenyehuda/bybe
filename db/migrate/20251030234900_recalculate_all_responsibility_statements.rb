# frozen_string_literal: true

class RecalculateAllResponsibilityStatements < ActiveRecord::Migration[8.0]
  def up
    total_count = Manifestation.count
    processed_count = 0
    
    print "Recalculating responsibility statements for #{total_count} manifestations... "
    Manifestation.find_each do |manifestation|
      begin
        manifestation.recalc_responsibility_statement!
        processed_count += 1
        
        if processed_count % 200 == 0
          print "\nProcessed #{processed_count}/#{total_count} manifestations... "
        end
      rescue StandardError => e
        Rails.logger.error("Failed to recalculate responsibility_statement for Manifestation #{manifestation.id}: #{e.message}")
      end
    end
    puts "\nCompleted! Processed #{processed_count}/#{total_count} manifestations."
  end

  def down
    # No need to revert this data migration
  end
end
