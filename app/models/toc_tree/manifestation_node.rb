# frozen_string_literal: true

module TocTree
  # Manifestation node
  class ManifestationNode
    attr_reader :manifestation

    def initialize(manifestation)
      @manifestation = manifestation
    end

    def id
      @id ||= "manifestation:#{@manifestation.id}"
    end

    def visible?(role, authority_id, involved_on_collection_level, parent_collection = nil)
      # When called from a collection context, only check involvement in that specific collection's hierarchy
      # This prevents a manifestation from appearing at collection-level just because it has involvement
      # in a different collection's hierarchy
      parent_collections = if parent_collection
                             [parent_collection]
                           else
                             @manifestation.collection_items.map(&:collection)
                           end

      involved_in_parent = involved_in_parent_collection(
        parent_collections,
        role,
        authority_id
      )

      return involved_in_parent if involved_on_collection_level

      involvement_check = @manifestation.involved_authorities_by_role(role).any? { |a| a.id == authority_id }
      return involvement_check && !involved_in_parent
    end

    # Count manifestations (1 if visible and published, 0 otherwise)
    def count_manifestations(role, authority_id, involved_on_collection_level, parent_collection = nil)
      return 0 unless visible?(role, authority_id, involved_on_collection_level, parent_collection)
      return 0 unless @manifestation.status == 'published'

      1
    end

    private

    def involved_in_parent_collection(parent_collections, role, authority_id)
      if parent_collections.empty?
        return false
      end

      upper_level = []

      parent_collections.each do |col|
        return true if col.involved_authorities.any? do |ia|
          ia.role == role.to_s && ia.authority_id == authority_id
        end

        upper_level += col.parent_collections
      end

      return involved_in_parent_collection(upper_level.uniq, role, authority_id)
    end
  end
end
