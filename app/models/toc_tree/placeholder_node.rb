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
      # Placeholder should be visible if authority is involved anywhere in the parent collection hierarchy.
      # We check recursively up the hierarchy (same logic as ManifestationNode) to handle cases where the
      # authority is involved in a grandparent collection but not directly in the immediate parent.
      check_collections = [parent_collection || @collection_item.collection]
      involved_in_parent = involved_in_parent_collection(check_collections, role, authority_id)
      return involved_in_parent if involved_on_collection_level

      # On work level, placeholders are only shown as part of a nested series listed in its entirety
      !involved_in_parent && involved_in_parent_series(check_collections, role, authority_id)
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
