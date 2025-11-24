# frozen_string_literal: true

# Service fetches/preload all manifestations and sub-collections within a given collection
# Call it before doing any processing on collection contents to avoid N+1 queries
class FetchCollection < ApplicationService
  attr_reader :all_manifestations

  def call(collection)
    @all_manifestations = []
    @all_collections = []

    collections = [collection]
    collections = fetch_children(collections) until collections.empty?

    collections = [collection]
    collections = fetch_parents(collections) until collections.empty?

    ActiveRecord::Associations::Preloader.new(
      records: @all_manifestations,
      associations: [
        :recommendations,
        {
          expression: {
            involved_authorities: :authority,
            work: { involved_authorities: :authority }
          }
        }
      ]
    ).call

    ActiveRecord::Associations::Preloader.new(
      records: @all_collections,
      associations: { involved_authorities: :authority }
    ).call

    self
  end

  private

  def fetch_parents(collections)
    next_level = []

    ActiveRecord::Associations::Preloader.new(
      records: collections,
      associations: { parent_collection_items: :collection }
    ).call

    collections.each do |col|
      col.parent_collection_items.each do |pci|
        parent_col = pci.collection
        unless @all_collections.include?(parent_col)
          next_level << parent_col
          @all_collections << parent_col
        end
      end
    end
    next_level
  end

  def fetch_children(collections)
    next_level = []
    @all_collections += collections

    ActiveRecord::Associations::Preloader.new(
      records: collections,
      associations: { collection_items: :item }
    ).call

    collections.each do |col|
      items = col.collection_items.map(&:item)
      next_level += items.select { |item| item&.is_a?(Collection) }
      @all_manifestations += items.select { |item| item&.is_a?(Manifestation) }
    end
    next_level
  end
end
