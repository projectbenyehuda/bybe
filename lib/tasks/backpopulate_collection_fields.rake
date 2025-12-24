desc "Backpopulate in_volume and in_periodical fields in ManifestationsIndex"
task :backpopulate_collection_fields => :environment do
  puts "Backpopulating in_volume and in_periodical fields in ManifestationsIndex..."
  puts "This will reindex all manifestations to compute collection containment."
  puts ""

  # Get total count
  total = Manifestation.all_published.indexable.count
  puts "Total manifestations to index: #{total}"
  puts ""

  # Reset the index (this will recreate it with the new fields and reindex all documents)
  puts "Resetting ManifestationsIndex..."
  ManifestationsIndex.reset!

  puts ""
  puts "Backpopulation complete!"
  puts "All #{total} manifestations have been reindexed with in_volume and in_periodical fields."
end
