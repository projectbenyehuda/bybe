# frozen_string_literal: true

module TocTree
  # Shared mixin providing a recursive authority-involvement check up the collection hierarchy.
  # Included by ManifestationNode and PlaceholderNode so both use identical traversal logic.
  module CollectionHierarchy
    private

    # Returns true if the given authority (authority_id / role) is involved on collection level in any collection
    # reachable by walking up the parent_collections chain from `collections`. Credit on a nested series does not
    # count (see Collection#nested_series?).
    def involved_in_parent_collection(collections, role, authority_id)
      credited_in_ancestors(collections, role, authority_id) { |col| !col.nested_series? }
    end

    # Returns true if the given authority is credited on a nested series somewhere up the parent_collections chain.
    # Such a series is listed in its entirety in the authority's work-level TOC section.
    def involved_in_parent_series(collections, role, authority_id)
      credited_in_ancestors(collections, role, authority_id, &:nested_series?)
    end

    # Walks up the hierarchy looking for a collection crediting the authority in the given role, and for which
    # the given block returns true
    def credited_in_ancestors(collections, role, authority_id, &)
      return false if collections.empty?

      upper_level = []
      collections.each do |col|
        credited = col.involved_authorities.any? { |ia| ia.role == role.to_s && ia.authority_id == authority_id }
        return true if credited && yield(col)

        upper_level += col.parent_collections
      end

      credited_in_ancestors(upper_level.uniq, role, authority_id, &)
    end
  end
end
