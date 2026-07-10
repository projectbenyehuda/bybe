# frozen_string_literal: true

# Precomputes the data needed by the Authority TOC "filters" pane (bead ln5) and
# by the in-browser filtering of the flat manifestation list:
#   * sets of manifestation IDs bearing each "curatorial" property, and
#   * the genres and source languages actually represented among the
#     manifestations the authority is involved with (in any role).
#
# "Curatorial content" means any of: a featuring (FeaturedContent), an approved
# Recommendation, an incoming Aboutness (another work that is ABOUT the
# manifestation), or an approved Tagging (on the manifestation itself, or on any
# collection that contains the manifestation on this author's page, including via
# nested sub-collections).
#
# This touches several tables and is only needed by the minority of visitors who
# change the TOC sort order, so callers are expected to cache the result per
# author (see AuthorsController#toc).
class AuthorTocFilterData < ApplicationService
  def call(authority)
    manifestation_ids = authority.published_manifestations.pluck(:id)

    {
      featured_ids: featured_ids(manifestation_ids),
      recommended_ids: recommended_ids(manifestation_ids),
      aboutness_ids: aboutness_ids(manifestation_ids),
      tagging_ids: tagging_ids(manifestation_ids, authority),
      genres: genres(manifestation_ids),
      orig_langs: orig_langs(manifestation_ids)
    }
  end

  private

  def featured_ids(ids)
    FeaturedContent.where(manifestation_id: ids).distinct.pluck(:manifestation_id).to_set
  end

  def recommended_ids(ids)
    Recommendation.approved.where(manifestation_id: ids).distinct.pluck(:manifestation_id).to_set
  end

  def aboutness_ids(ids)
    Aboutness.where(aboutable_type: 'Manifestation', aboutable_id: ids).distinct.pluck(:aboutable_id).to_set
  end

  # Manifestations bearing an approved Tagging, either directly or by belonging to
  # a collection (on this author's page) that itself bears an approved Tagging.
  def tagging_ids(ids, authority)
    direct = Tagging.approved.where(taggable_type: 'Manifestation', taggable_id: ids)
                    .distinct.pluck(:taggable_id).to_set
    direct.merge(collection_tagged_manifestation_ids(ids, authority))
  end

  # Manifestation ids reachable from an approved-tagged collection, restricted to
  # the author's own manifestations (ids). A collection counts as "on the author's
  # page" if the author is directly involved in it OR it is nested (any depth)
  # under such a collection; a tagging on either cascades to the manifestations it
  # contains (also any depth).
  def collection_tagged_manifestation_ids(ids, authority)
    page_collection_ids = page_collection_ids(authority)
    return Set.new if page_collection_ids.empty?

    tagged_collection_ids = Tagging.approved
                                   .where(taggable_type: 'Collection', taggable_id: page_collection_ids)
                                   .distinct.pluck(:taggable_id)
    return Set.new if tagged_collection_ids.empty?

    id_set = ids.to_set
    Collection.where(id: tagged_collection_ids).each_with_object(Set.new) do |collection, acc|
      collection.flatten_items.each do |ci|
        acc << ci.item_id if ci.item_type == 'Manifestation' && id_set.include?(ci.item_id)
      end
    end
  end

  # Ids of every collection appearing on the author's page: those the author is
  # directly involved in, plus all sub-collections nested under them (any depth).
  def page_collection_ids(authority)
    roots = authority.collections.pluck(:id)
    return roots if roots.empty?

    ids = roots.to_set
    Collection.where(id: roots).find_each do |collection|
      collection.flatten_items.each do |ci|
        ids << ci.item_id if ci.item_type == 'Collection'
      end
    end
    ids.to_a
  end

  # genres present, ordered by the canonical genre presentation order
  def genres(ids)
    present = Manifestation.where(id: ids).joins(expression: :work).distinct.pluck('works.genre').compact
    Work::GENRES & present
  end

  # source languages present, e.g. ['he', 'ru', ...]
  def orig_langs(ids)
    Manifestation.where(id: ids).joins(expression: :work).distinct.pluck('works.orig_lang').compact
  end
end
