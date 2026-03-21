# frozen_string_literal: true

module TocTree
  # Placeholder node
  class PlaceholderNode
    include TocTree::CollectionHierarchy

    attr_reader :collection_item

    def initialize(collection_item)
      @collection_item = collection_item
    end

    def id
      @id ||= "placeholder:#{@collection_item.id}"
    end

    def visible?(role, authority_id, involved_on_collection_level, parent_collection = nil)
      # Placeholders should only be visible if authority is involved on collection level
      return false unless involved_on_collection_level

      # Placeholder should be visible if authority is involved anywhere in the parent collection hierarchy.
      # We check recursively up the hierarchy (same logic as ManifestationNode) to handle cases where the
      # authority is involved in a grandparent collection but not directly in the immediate parent.
      check_collection = parent_collection || @collection_item.collection
      involved_in_parent_collection([check_collection], role, authority_id)
    end

    def alt_title
      @collection_item.alt_title
    end

    def markdown
      @collection_item.markdown
    end

    # Placeholders don't contain manifestations
    def count_manifestations(_role, _authority_id, _involved_on_collection_level, _parent_collection = nil)
      0
    end
  end
end
