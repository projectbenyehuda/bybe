# frozen_string_literal: true

# We want to group all works author was involved into but not belonging to any colleciton into a special
# 'Uncollected works' collection
class RefreshUncollectedWorksCollection < ApplicationService
  def call(authority)
    # Wrap in transaction and use pessimistic locking to prevent race conditions
    # where multiple concurrent calls create orphaned collections
    Authority.transaction do
      # Lock the authority to prevent concurrent modifications
      locked_authority = Authority.lock.find(authority.id)

      # Re-check for existing collection inside the lock (may have been created by another thread)
      collection = locked_authority.uncollected_works_collection

      remove_collected_works(locked_authority) if collection.present?

      is_new_collection = collection.nil?

      if is_new_collection
        collection = Collection.new(
          collection_type: :uncollected,
          title: I18n.t(:uncollected_works_collection_title)
        )
        collection.allow_system_type_change!
      end

      # Disable automatic manifestations_count updates during bulk add
      collection.skip_manifestations_count_update = true

      nextseqno = (collection.collection_items.maximum(:seqno) || 0) + 1

      # Checking all manifestations given authority is involved into as author or translator
      locked_authority.published_manifestations(:author, :translator, :editor) # TODO: consider other roles?
                      .preload(collection_items: :collection)
                      .find_each do |m|
        # skipping if manifestation is included in some other collection or already included in uncollected works
        # collection for this authority
        next if m.collection_items.any? do |ci|
          !ci.collection.uncollected? || (collection.present? && ci.collection == collection)
        end

        collection.collection_items.build(item: m, seqno: nextseqno)
        nextseqno += 1
      end

      # Save collection first
      collection.save!

      # Link collection to authority and save - this ensures referential integrity within transaction
      # If this was a new collection, link it to the authority now
      if is_new_collection
        locked_authority.uncollected_works_collection = collection
        locked_authority.save!
      elsif locked_authority.changed?
        locked_authority.save!
      end

      # Re-enable automatic updates and manually recalculate the count
      collection.skip_manifestations_count_update = false
      collection.recalculate_manifestations_count!
    end
  end

  # removes from uncollected_works collection works which was included in some other collection
  def remove_collected_works(authority)
    authority.uncollected_works_collection
             .collection_items
             .preload(item: { collection_items: :collection })
             .find_each do |collection_item|
      # The only possible item type in uncollected works collection is Manifestation
      manifestation = collection_item.item
      # NOTE: same work can be in several different uncollected works collection related to different authorities

      if manifestation.blank? || manifestation.collection_items.any? { |ci| !ci.collection.uncollected? }
        collection_item.destroy!
      end
    end
  end
end
