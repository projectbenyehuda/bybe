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
    def visible?(role, authority_id, involved_on_collection_level)
      involvement_check = @collection.involved_authorities.any? do |ia|
        ia.role == role.to_s && ia.authority_id == authority_id
      end

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
      @children_by_role["#{role}_#{involved_on_collection_level}"] ||= sorted_children.select do |child|
        child.visible?(role, authority_id, involved_on_collection_level)
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

    # Count manifestations recursively in this collection and its children
    def count_manifestations(role, authority_id, involved_on_collection_level)
      return 0 unless visible?(role, authority_id, involved_on_collection_level)

      children_by_role(role, authority_id, involved_on_collection_level).sum do |child|
        child.count_manifestations(role, authority_id, involved_on_collection_level)
      end
    end
  end
end
