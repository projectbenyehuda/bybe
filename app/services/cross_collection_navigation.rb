# frozen_string_literal: true

# Finds the previous/next manifestation when navigating across sub-collection
# boundaries within a parent collection of type 'volume' or 'periodical_issue'.
#
# Usage: CrossCollectionNavigation.call(manifestation, sub_collection)
# Returns an object with #prev_in_parent and #next_in_parent (Manifestation or nil).
# Returns nil from both methods when the sub_collection has no volume/issue ancestor.
class CrossCollectionNavigation < ApplicationService
  def call(manifestation, sub_collection)
    @parent = find_parent_volume_or_issue(sub_collection)
    if @parent
      @flat = flatten_manifestations(@parent)
      @index = @flat.find_index { |m| m.id == manifestation.id }
    end
    self
  end

  def prev_in_parent
    return nil unless @parent && @index && @index > 0

    @flat[@index - 1]
  end

  def next_in_parent
    return nil unless @parent && @index && @index < @flat.length - 1

    @flat[@index + 1]
  end

  private

  def find_parent_volume_or_issue(collection)
    queue = collection.parent_collections.dup
    visited = Set.new
    while queue.any?
      pc = queue.shift
      next if visited.include?(pc.id)

      visited.add(pc.id)
      return pc if pc.volume? || pc.periodical_issue?

      queue.concat(pc.parent_collections)
    end
    nil
  end

  def flatten_manifestations(collection)
    # Direct query avoids stale inverse_of cache; preload :item avoids N+1 per row
    CollectionItem.where(collection: collection).order(:seqno).preload(:item).flat_map do |ci|
      next [] if ci.item_id.nil?

      if ci.item_type == 'Manifestation' && ci.item.present?
        [ci.item]
      elsif ci.item_type == 'Collection' && ci.item.present?
        flatten_manifestations(ci.item)
      else
        []
      end
    end
  end
end
