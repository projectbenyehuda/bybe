# frozen_string_literal: true

class FixInvalidUncollectedWorksCollectionReferences < ActiveRecord::Migration[8.0]
  def up
    print "Fixing invalid uncollected_works_collection_id references... "
    count = 0

    # Find all authorities that have an uncollected_works_collection_id pointing to a collection
    # that is NOT of type 'uncollected'
    Authority.where.not(uncollected_works_collection_id: nil).find_each do |authority|
      collection = Collection.find_by(id: authority.uncollected_works_collection_id)
      
      # If collection doesn't exist or is not of type 'uncollected', clear the reference
      if collection.nil? || collection.collection_type != Collection.collection_types[:uncollected]
        authority.update_column(:uncollected_works_collection_id, nil)
        count += 1
      end
    end

    puts "#{count} invalid reference(s) cleared."
  end

  def down
    # This migration is irreversible as we're cleaning up invalid data
    raise ActiveRecord::IrreversibleMigration
  end
end
