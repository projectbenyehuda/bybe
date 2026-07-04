# frozen_string_literal: true

# Finds the previous/next sibling volume of a given volume within its containing
# volume_series collection, so Collection#show can offer prev/next volume navigation
# (mirroring the cross-collection navigation offered in Manifestation#read).
#
# Usage: FindSeriesVolumeSiblings.call(volume_collection)
# Exposes #series (the containing volume_series Collection, or nil), #prev_volume, #next_volume.
class FindSeriesVolumeSiblings < ApplicationService
  def call(collection)
    @series = collection.parent_collections.find(&:volume_series?)
    if @series
      @volumes = sibling_volumes(@series)
      @index = @volumes.find_index { |c| c.id == collection.id }
    end
    self
  end

  attr_reader :series

  def prev_volume
    return nil unless @index&.positive?

    @volumes[@index - 1]
  end

  def next_volume
    return nil unless @index && @index < @volumes.length - 1

    @volumes[@index + 1]
  end

  private

  # Direct volume children of the series, in seqno order
  def sibling_volumes(series)
    CollectionItem.where(collection: series, item_type: 'Collection').order(:seqno).preload(:item).filter_map do |ci|
      c = ci.item
      c if c.present? && c.volume?
    end
  end
end
