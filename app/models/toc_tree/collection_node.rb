# frozen_string_literal: true

module TocTree
  # Collection node
  class CollectionNode
    attr_accessor :collection, :children, :new, :has_parents

    # Item is a collection
    # Children is an array of [x, seqno] where x is a Node (Collection/Manifestation/Placeholder),
    # seqno used for ordering
    def initialize(collection)
      @collection = collection
      @children = []
      @new = true
      @parents = []
      @has_parents = false
    end

    def id
      @id ||= "collection:#{@collection.id}"
    end

    def add_child(child, seqno)
      return if child.nil?

      @children << [child, seqno] unless @children.any? { |ch, _seqno| ch.id == child.id }
      child.has_parents = true if child.is_a?(TocTree::CollectionNode)
    end

    # Checks if given Node should be displayed in TOC tree for given authority and role combination
    # @param role [String] role of authority
    # @param authority_id [Integer] id of authority
    # @param involved_on_collection_level [Boolean] mode of check: if true we check if authority is involved on
    #   collection level (and optionally at work level), otherwise we check if authority is NOT involved on
    #   collection level
    # @param parent_collection [Collection] optional parent collection context (not used for CollectionNode,
    #   but needed for signature consistency with other node types)
    def visible?(role, authority_id, involved_on_collection_level, parent_collection = nil)
      # credit on a nested series is not collection-level involvement: such a series is listed on work level
      involvement_check = involved?(role, authority_id) && !@collection.nested_series?

      if involved_on_collection_level
        return true if involvement_check
      elsif !@collection.uncollected?
        return false if involvement_check
      end

      # Checking if collection contains visible children (recursive check)
      return children_by_role(role, authority_id, involved_on_collection_level).present?
    end

    # Returns array of child elements (Manifestations or Nodes) where given author is involved with given role
    def children_by_role(role, authority_id, involved_on_collection_level)
      @children_by_role ||= {}
      @children_by_role["#{role}_#{involved_on_collection_level}"] ||=
        if collapsed_for?(role, authority_id)
          []
        else
          sorted_children.select do |child|
            child.visible?(role, authority_id, involved_on_collection_level, @collection)
          end
        end
    end

    # Whether this collection is shown collapsed on the given authority's page under the given role:
    # a collection the authority edited is listed by title (linking to the collection) on the editor's
    # page, but the texts in it are its authors' works, so they are neither listed nor counted there,
    # and hence not offered in the flat list or its filters either, which are built from the listed texts.
    def collapsed_for?(role, authority_id)
      role.to_s == 'editor' && involved?(role, authority_id)
    end

    # Whether this is a periodical or periodical issue edited by the given authority, i.e. one in which the
    # authority's works listed on work level appear in a title of their own editing rather than someone else's.
    # A periodical counts if the authority edits it, or edits every issue of it listed on work level.
    def edited_periodical?(role, authority_id)
      return false unless @collection.periodical? || @collection.periodical_issue?
      return true if involved?('editor', authority_id)
      return false unless @collection.periodical?

      issues = children_by_role(role, authority_id, false)
      issues.present? && issues.all? do |child|
        child.is_a?(TocTree::CollectionNode) && child.collection.periodical_issue? &&
          child.edited_periodical?(role, authority_id)
      end
    end

    def sorted_children
      @sorted_children ||= children.sort_by { |child, seqno| [seqno, child.id] }.map(&:first)
    end

    # Criteria used to sort collection nodes in TOC tree
    def sort_term
      [
        @collection.normalized_pub_year.presence || @collection.created_at.year,
        @collection.id
      ]
    end

    # Count manifestations recursively in this collection and its children.
    # Result is memoized per (role, authority_id, involved_on_collection_level); parent_collection
    # is accepted for interface consistency with ManifestationNode but is unused here since
    # CollectionNode#visible? derives involvement from its own involved_authorities.
    def count_manifestations(role, authority_id, involved_on_collection_level, parent_collection = nil)
      @manifestation_counts ||= {}
      cache_key = "#{role}_#{authority_id}_#{involved_on_collection_level}"
      return @manifestation_counts[cache_key] if @manifestation_counts.key?(cache_key)

      count = if visible?(role, authority_id, involved_on_collection_level, parent_collection)
                children_by_role(role, authority_id, involved_on_collection_level).sum do |child|
                  child.count_manifestations(role, authority_id, involved_on_collection_level, @collection)
                end
              else
                0
              end
      @manifestation_counts[cache_key] = count
    end

    private

    # Whether the authority is credited with the given role on this collection itself
    def involved?(role, authority_id)
      @collection.involved_authorities.any? { |ia| ia.role == role.to_s && ia.authority_id == authority_id }
    end
  end
end
