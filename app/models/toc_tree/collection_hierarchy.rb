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
      ancestor_credits(collections, role, authority_id)[:collection_level]
    end

    # Returns true if the given authority is credited on a nested series somewhere up the parent_collections chain.
    # Such a series is listed in its entirety in the authority's work-level TOC section. Only meaningful when
    # involved_in_parent_collection is false, as the walk stops once collection-level credit is found.
    def involved_in_parent_series(collections, role, authority_id)
      ancestor_credits(collections, role, authority_id)[:nested_series]
    end

    # Walks up the hierarchy once, classifying the collections crediting the authority in the given role into
    # collection-level ones and nested series. Memoized, as visible? is asked repeatedly for the same context.
    def ancestor_credits(collections, role, authority_id)
      role = role.to_s
      @ancestor_credits ||= {}
      @ancestor_credits[[collections.map(&:id), role, authority_id]] ||= begin
        credits = { collection_level: false, nested_series: false }
        seen = Set.new
        level = collections
        # collection-level credit settles every question callers ask, so there is no need to walk further
        until level.empty? || credits[:collection_level]
          level = level.select { |col| seen.add?(col.id) }
          level.each do |col|
            next unless col.involved_authorities.any? { |ia| ia.role == role && ia.authority_id == authority_id }

            credits[col.nested_series? ? :nested_series : :collection_level] = true
          end
          level = level.flat_map(&:parent_collections)
        end
        credits
      end
    end
  end
end
