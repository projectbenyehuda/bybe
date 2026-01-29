# frozen_string_literal: true

desc 'Clean up orphaned uncollected collections created by race conditions'
task :cleanup_orphaned_uncollected_collections, [:execute] => :environment do |_task, args|
  execute_mode = args[:execute] == 'execute'

  puts '=' * 80
  puts 'Cleanup Orphaned Uncollected Collections'
  puts '=' * 80
  puts ''

  if execute_mode
    puts 'Running in EXECUTE mode - changes will be saved to database'
  else
    puts 'Running in DRY-RUN mode - no changes will be saved'
    puts 'To execute changes, run: rake cleanup_orphaned_uncollected_collections[execute]'
  end
  puts ''

  stats = {
    orphaned_found: 0,
    fixed_by_linking: 0,
    deleted_empty: 0,
    deleted_unfixable: 0
  }

  # Find all uncollected collections NOT linked to any authority
  linked_collection_ids = Authority.where.not(uncollected_works_collection_id: nil)
                                   .pluck(:uncollected_works_collection_id)
  orphaned_collections = Collection.where(collection_type: :uncollected)
                                   .where.not(id: linked_collection_ids)

  puts "Found #{orphaned_collections.count} orphaned uncollected collection(s)"
  puts ''

  orphaned_collections.find_each do |collection|
    stats[:orphaned_found] += 1
    item_count = collection.collection_items.count

    puts "Processing Collection ID #{collection.id} (#{item_count} items)..."

    # Try to identify authority by examining collection_items
    potential_authority = identify_authority_from_items(collection)

    if potential_authority && potential_authority.uncollected_works_collection.nil?
      # Can link it!
      puts "  → Can link to Authority #{potential_authority.id} (#{potential_authority.name})"
      if execute_mode
        potential_authority.update!(uncollected_works_collection: collection)
        stats[:fixed_by_linking] += 1
        puts '  ✓ Linked successfully'
      else
        puts '  [DRY-RUN] Would link to authority'
      end
    elsif potential_authority && potential_authority.uncollected_works_collection.present?
      # Authority already has a collection
      collection_id = potential_authority.uncollected_works_collection_id
      puts "  ⚠ Authority #{potential_authority.id} already has an uncollected collection (ID: #{collection_id})"
      puts '  → Will delete this orphaned duplicate'
      if execute_mode
        collection.destroy!
        stats[:deleted_unfixable] += 1
        puts '  ✓ Deleted duplicate collection'
      else
        puts '  [DRY-RUN] Would delete duplicate collection'
      end
    elsif item_count == 0
      # Empty orphan - safe to delete
      puts '  → Empty collection, will delete'
      if execute_mode
        collection.destroy!
        stats[:deleted_empty] += 1
        puts '  ✓ Deleted empty collection'
      else
        puts '  [DRY-RUN] Would delete empty collection'
      end
    else
      # Has items but can't link - delete with warning
      puts '  ⚠ WARNING: Cannot determine owning authority'
      puts "  → Will delete collection with #{item_count} item(s)"
      if execute_mode
        collection.destroy!
        stats[:deleted_unfixable] += 1
        puts '  ✓ Deleted unfixable collection'
      else
        puts '  [DRY-RUN] Would delete unfixable collection'
      end
    end

    puts ''
  end

  # Print summary
  puts '=' * 80
  puts 'Summary'
  puts '=' * 80
  puts ''
  puts "Orphaned collections found:      #{stats[:orphaned_found]}"
  puts "Collections linked to authority: #{stats[:fixed_by_linking]}"
  puts "Empty collections deleted:       #{stats[:deleted_empty]}"
  puts "Unfixable collections deleted:   #{stats[:deleted_unfixable]}"
  puts ''

  if execute_mode
    puts '✓ Cleanup completed successfully'
  else
    puts 'ℹ This was a dry-run. No changes were made.'
    puts '  Run with [execute] argument to apply changes.'
  end

  puts ''
end

# Helper method to identify the owning authority from collection items
def identify_authority_from_items(collection)
  # Get all authorities from collection items by examining manifestations
  authority_ids = []

  collection.collection_items.where(item_type: 'Manifestation').includes(item: { expression: :work }).find_each do |ci|
    next if ci.item.blank?

    manifestation = ci.item

    # Get authorities from both work and expression level (authors, translators, editors)
    # We prioritize work-level authorities (authors) over expression-level (translators, editors)
    work_authority_ids = InvolvedAuthority.where(item_id: manifestation.expression.work_id, item_type: 'Work')
                                          .where(role: %i(author illustrator))
                                          .pluck(:authority_id)
    expression_authority_ids = InvolvedAuthority.where(item_id: manifestation.expression_id, item_type: 'Expression')
                                                .where(role: %i(translator editor))
                                                .pluck(:authority_id)

    # Prioritize work-level authorities (authors) since uncollected collections typically belong to authors
    authority_ids += if work_authority_ids.any?
                       work_authority_ids
                     else
                       expression_authority_ids
                     end
  end

  authority_ids = authority_ids.uniq

  # If all items belong to same authority, that's likely the owner
  return nil unless authority_ids.length == 1

  Authority.find_by(id: authority_ids.first)
end
