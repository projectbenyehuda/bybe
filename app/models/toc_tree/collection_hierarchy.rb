# frozen_string_literal: true

module TocTree
  # Shared mixin providing a recursive authority-involvement check up the collection hierarchy.
  # Included by ManifestationNode and PlaceholderNode so both use identical traversal logic.
  module CollectionHierarchy
    private

    # Returns true if the given authority (authority_id / role) is listed in the involved_authorities
    # of any collection reachable by walking up the parent_collections chain from `collections`.
    def involved_in_parent_collection(collections, role, authority_id)
      return false if collections.empty?

      upper_level = []
      collections.each do |col|
        return true if col.involved_authorities.any? { |ia| ia.role == role.to_s && ia.authority_id == authority_id }

        upper_level += col.parent_collections
      end

      involved_in_parent_collection(upper_level.uniq, role, authority_id)
    end
  end
end
