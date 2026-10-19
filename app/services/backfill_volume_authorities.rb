# frozen_string_literal: true

# Finds volume collections that have no involved_authorities of their own (and so are invisible to
# Authority#volumes) and, where it is unambiguous, gives them one.
#
# A volume is assigned an authority only when every manifestation it contains (descending into
# sub-collections) has exactly the same single author. Anything else -- no manifestations, a
# manifestation with no author or several, manifestations that disagree, or a shared author that is
# pageless ("anonymous", "various authors") -- is left alone and
# reported for human review. Volumes inside a volume_series are skipped: Authority#volumes_including_series
# already reaches them.
#
# Usage: BackfillVolumeAuthorities.call(dry_run: false)
# Exposes #assigned and #needs_review, each an array of Result structs.
class BackfillVolumeAuthorities < ApplicationService
  Result = Struct.new(:collection, :item_count, :authorities, :reason, keyword_init: true)

  attr_reader :assigned, :needs_review

  def call(dry_run: false)
    @assigned = []
    @needs_review = []

    candidates.find_each do |volume|
      result = analyze(volume)
      if result.reason.nil?
        InvolvedAuthority.create!(item: volume, authority: result.authorities.first, role: :author) unless dry_run
        @assigned << result
      else
        @needs_review << result
      end
    end
    self
  end

  private

  def candidates
    in_series = CollectionItem.joins(:collection)
                              .where(item_type: 'Collection', collections: { collection_type: 'volume_series' })
                              .select(:item_id)
    Collection.where(collection_type: 'volume')
              .where.not(id: InvolvedAuthority.where(item_type: 'Collection').select(:item_id))
              .where.not(id: in_series)
  end

  def analyze(volume)
    manifestations = contained_manifestations(volume)
    per_item = manifestations.map { |m| m.authors.uniq }
    authorities = per_item.flatten.uniq.sort_by(&:id)

    reason =
      if manifestations.empty? then 'no_manifestations'
      elsif per_item.any?(&:empty?) then 'item_without_author'
      elsif authorities.size > 1 then 'multiple_authorities'
      elsif authorities.first.pageless? then 'pageless_authority'
      end

    Result.new(collection: volume, item_count: manifestations.size, authorities: authorities, reason: reason)
  end

  # Manifestations in the volume, descending into sub-collections (cycle-safe).
  def contained_manifestations(collection, seen = Set.new)
    return [] unless seen.add?(collection.id)

    collection.collection_items.includes(:item).flat_map do |ci|
      case ci.item
      when Manifestation then [ci.item]
      when Collection then contained_manifestations(ci.item, seen)
      else []
      end
    end
  end
end
