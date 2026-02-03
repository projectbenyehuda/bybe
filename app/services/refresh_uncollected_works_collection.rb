# frozen_string_literal: true

# We want to group all works author was involved into but not belonging to any colleciton into a special
# 'Uncollected works' collection
class RefreshUncollectedWorksCollection < ApplicationService
  # Uncollected works collection should only contain works where authority is involved as author, translator or editor
  ROLES = %i(author translator editor).freeze

  # rubocop:disable Style/GuardClause
  def call(authority)
    Authority.transaction do
      authority.lock!
      collection = authority.uncollected_works_collection

      remove_collected_works(authority) if collection.present?

      if collection.nil?
        collection = Collection.new(
          collection_type: :uncollected,
          title: I18n.t(:uncollected_works_collection_title)
        )
        collection.allow_system_type_change!
      end

      # Disable automatic manifestations_count updates during bulk add
      collection.skip_manifestations_count_update = true

      nextseqno = (collection.collection_items.maximum(:seqno) || 0) + 1

      # Checking all manifestations given authority is involved into with required roles
      authority.published_manifestations(*ROLES)
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

      collection.save! # should save all added items

      # Re-enable automatic updates and manually recalculate the count
      collection.skip_manifestations_count_update = false
      collection.recalculate_manifestations_count! if collection.persisted?

      if authority.uncollected_works_collection.nil?
        authority.uncollected_works_collection = collection
        authority.save!
      end
    end
  end
  # rubocop:enable Style/GuardClause

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
