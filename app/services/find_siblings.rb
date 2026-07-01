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

  # returns true if there are non-paratext collection items before the current one
  def more_before?
    @items[0...@index].any? { |ci| !ci.paratext? }
  end

  # returns true if there are non-paratext collection items after the current one
  def more_after?
    @items[(@index + 1)..].any? { |ci| !ci.paratext? }
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
      if ci.item_type == 'Collection'
        if ci.item.present?
          m = step > 0 ? first_manifestation_in(ci.item) : last_manifestation_in(ci.item)
          return { item: m, skipped: skipped } if m.present?
        end
        skipped += 1
        next
      end
      return { item: ci.item, skipped: skipped }
    end
    nil
  end

  def first_manifestation_in(collection)
    CollectionItem.where(collection: collection).order(:seqno).preload(:item).each do |ci|
      next if ci.item_id.nil?

      return ci.item if ci.item_type == 'Manifestation' && ci.item.present?

      if ci.item_type == 'Collection' && ci.item.present?
        found = first_manifestation_in(ci.item)
        return found if found.present?
      end
    end
    nil
  end

  def last_manifestation_in(collection)
    CollectionItem.where(collection: collection).order(seqno: :desc).preload(:item).each do |ci|
      next if ci.item_id.nil?

      return ci.item if ci.item_type == 'Manifestation' && ci.item.present?

      if ci.item_type == 'Collection' && ci.item.present?
        found = last_manifestation_in(ci.item)
        return found if found.present?
      end
    end
    nil
  end
end
