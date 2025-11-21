# frozen_string_literal: true

# Service to generate collections-based TOC tree for a single authority
class GenerateTocTree < ApplicationService
  # Node represents a single collection

  def call(authority)
    @authority = authority
    @collection_nodes = {}

    build_collection_tree
    fetch_manifestations

    current_level = top_level_nodes

    current_level = get_parents(current_level) until current_level.empty?

    top_level_nodes
  end

  private

  def top_level_nodes
    @collection_nodes.values.reject(&:has_parents)
  end

  # This is a first step of building TOC tree
  # We check all collections where authority is involved on collection level and fetch all their children
  # down to the bottom
  def build_collection_tree
    # Fetching all collections authority is directly involved into on collection level
    nodes = @authority.collections.map do |collection|
      collection_node(collection, nil, nil)
    end

    nodes = fetch_children(nodes) until nodes.empty?
  end

  # This is a second step of building TOC tree
  # We check all manifestations whene authority is directly involved, and fetching all their parent collections
  # NOTE: we assume every manifestation must be included at least in one collection (either 'normal' or 'uncollected')
  def fetch_manifestations
    manifestations = @authority.manifestations(:author, :translator, :editor)
                               .preload(collection_items: :collection).with_involved_authorities

    manifestations.each do |manifestation|
      manifestation.collection_items.each do |collection_item|
        col = collection_item.collection
        # We should not include in results 'uncollected' collections belonging to other authorities
        next if col.uncollected? && col.id != @authority.uncollected_works_collection_id

        collection_node(col, TocTree::ManifestationNode.new(manifestation), collection_item.seqno)
      end
    end
  end

  # Fetches children of given collection nodes and adds them as children to it
  # Returns list of child nodes representing other sub-collections (only not yet traversed)
  def fetch_children(parent_nodes)
    next_level = []

    all_parent_collections = parent_nodes.map(&:collection)

    ActiveRecord::Associations::Preloader.new(
      records: all_parent_collections,
      associations: { collection_items: :item, involved_authorities: :authority }
    ).call

    all_manifestation_children = all_parent_collections.map(&:collection_items).flatten
                                                       .map(&:item).select { |item| item.is_a?(Manifestation) }
    ActiveRecord::Associations::Preloader.new(
      records: all_manifestation_children,
      associations: { expression: { involved_authorities: :authority, work: { involved_authorities: :authority } } }
    ).call

    parent_nodes.each do |parent_node|
      parent_node.collection.collection_items.map do |ci|
        child_item = if ci.item.is_a?(Collection)
                       # nested collection
                       item = collection_node(ci.item, nil, nil)
                       item.has_parents = true
                       if item.new
                         next_level << item
                       end
                       item
                     elsif ci.item.is_a?(Manifestation)
                       # manifestation
                       TocTree::ManifestationNode.new(ci.item)
                     else
                       # placeholder
                       TocTree::PlaceholderNode.new(ci)
                     end

        parent_node.add_child(child_item, ci.seqno)
      end
    end
    next_level
  end

  # This method either creates a new node with given child, or finds existing node and adds child to it
  def collection_node(collection, child, seqno)
    node = @collection_nodes[collection.id]
    if node.nil?
      node = @collection_nodes[collection.id] = TocTree::CollectionNode.new(collection)
    else
      # This collection was already visited
      node.new = false # marking node as not new
    end

    node.add_child(child, seqno)
    node
  end

  def get_parents(nodes)
    ActiveRecord::Associations::Preloader.new(
      records: nodes.map(&:collection),
      associations: { involved_authorities: :authority, parent_collection_items: :collection }
    ).call

    parents = []
    nodes.each do |node|
      parent_collection_items = node.collection.parent_collection_items
      next if parent_collection_items.empty?

      parent_collection_items.each do |collection_item|
        parent_node = collection_node(collection_item.collection, node, collection_item.seqno)
        parents << parent_node if parent_node.new
      end
    end
    parents
  end
end
