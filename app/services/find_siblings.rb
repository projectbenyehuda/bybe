# frozen_string_literal: true

# Service to find previous and next siblings of an item in a collection, skipping placeholders
class FindSiblings < ApplicationService
  def call(manifestation, collection)
    @items = collection.collection_items.sort_by(&:seqno)
    @index = @items.find_index { |ci| ci.item_type == manifestation.class.name && ci.item_id == manifestation.id }

    raise 'Item not found in collection' if @index.nil?

    self
  end

  # returns the previous sibling that wraps an item, skipping placeholders. and returning count of skipped items
  def previous_sibling
    @previous_sibling ||= find_sibling(-1)
  end

  # returns the next sibling that wraps an item, skipping placeholders. and returning count of skipped items
  def next_sibling
    @next_sibling ||= find_sibling(1)
  end

  # returns true if there are collection items before the current one (even if all placeholders)
  def more_before?
    @index > 0
  end

  # returns true if there are collection items after the current one (even if all placeholders)
  def more_after?
    @index < @items.length - 1
  end

  private

  def find_sibling(step)
    to = step < 0 ? 0 : @items.length - 1
    skipped = 0
    i = @index
    until i == to
      i += step
      ci = @items[i]
      if ci.item_id.nil?
        skipped += 1
        next
      end
      return { item: ci.item, skipped: skipped }
    end
    nil
  end
end
