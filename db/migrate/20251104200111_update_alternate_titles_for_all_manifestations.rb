# frozen_string_literal: true

# Update alternate titles for all manifestations
class UpdateAlternateTitlesForAllManifestations < ActiveRecord::Migration[8.0]
  def up
    puts "Starting to update alternate titles for all manifestations..."
    
    total_count = Manifestation.count
    puts "Total manifestations to process: #{total_count}"
    
    processed_count = 0
    error_count = 0
    
    Manifestation.find_each do |manifestation|
      begin
        manifestation.update_alternate_titles
        manifestation.save!
        processed_count += 1
        
        # Print progress every 200 manifestations
        if (processed_count % 200).zero?
          puts "Processed #{processed_count}/#{total_count} manifestations (#{error_count} errors so far)"
        end
      rescue StandardError => e
        error_count += 1
        puts "ERROR: Failed to update manifestation ID #{manifestation.id}: #{e.message}"
      end
    end
    
    puts "Completed updating alternate titles!"
    puts "Total processed: #{processed_count}"
    puts "Total errors: #{error_count}"
  end

  def down
    # This migration cannot be reversed as it doesn't change schema
    puts "This migration cannot be reversed as it only updates data"
  end
end
