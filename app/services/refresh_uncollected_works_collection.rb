# frozen_string_literal: true

# We want to group all works author was involved into but not belonging to any colleciton into a special
# 'Uncollected works' collection
class RefreshUncollectedWorksCollection < ApplicationService
  # rubocop:disable Style/GuardClause
  def call(authority)
    collection = authority.uncollected_works_collection

    remove_collected_works(authority) if collection.present?

    if collection.nil?
      collection = Collection.new(
        collection_type: :uncollected,
        title: I18n.t(:uncollected_works_collection_title)
      )
      collection.allow_system_type_change!
    end

    nextseqno = (collection.collection_items.maximum(:seqno) || 0) + 1

    # Checking all manifestations given authority is involved into as author or translator
    authority.published_manifestations(:author, :translator, :editor) # TODO: consider other roles?
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

    if authority.uncollected_works_collection.nil?
      authority.uncollected_works_collection = collection
      authority.save!
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
