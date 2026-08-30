# frozen_string_literal: true

module TocTree
  # Manifestation node
  class ManifestationNode
    include TocTree::CollectionHierarchy

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

      return directly_involved?(role, authority_id) && !involved_in_parent
    end

    # Count manifestations (1 if visible, published and the authority's own, 0 otherwise).
    #
    # Visibility is deliberately broader than countability: a volume authored by X also *lists*
    # a preface someone else wrote, because the reader browsing that volume wants to see it. But
    # such a work is not one of X's, so it must not inflate the counts the author page shows
    # beside the metadata card's 'works in the project' figure, which counts direct involvements
    # only. Hence the extra involvement check here, which is what keeps the two in agreement.
    def count_manifestations(role, authority_id, involved_on_collection_level, parent_collection = nil)
      return 0 unless visible?(role, authority_id, involved_on_collection_level, parent_collection)
      return 0 unless @manifestation.status == 'published'
      return 0 unless directly_involved?(role, authority_id)

      1
    end

    private

    # Whether the authority is involved in this work itself (as opposed to merely in a collection
    # containing it) with the given role.
    #
    # Deliberately reads the involved_authorities rows rather than going through
    # Manifestation#involved_authorities_by_role, which materialises and name-sorts Authority
    # objects just to answer a membership question. This runs for every work in the TOC, once per
    # role, so it is memoized too. The preloads in GenerateTocTree cover both associations walked
    # here, so this issues no queries.
    def directly_involved?(role, authority_id)
      role = role.to_s
      raise "Unknown role #{role}" unless InvolvedAuthority.roles.key?(role)

      @directly_involved ||= {}
      key = "#{role}_#{authority_id}"
      return @directly_involved[key] if @directly_involved.key?(key)

      expression = @manifestation.expression
      @directly_involved[key] = [expression, expression.work].any? do |record|
        record.involved_authorities.any? { |ia| ia.role == role && ia.authority_id == authority_id }
      end
    end
  end
end
