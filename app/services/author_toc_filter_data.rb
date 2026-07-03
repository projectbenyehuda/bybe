# frozen_string_literal: true

# Precomputes the data needed by the Authority TOC "filters" pane (bead ln5) and
# by the in-browser filtering of the flat manifestation list:
#   * sets of manifestation IDs bearing each "curatorial" property, and
#   * the genres and source languages actually represented among the
#     manifestations the authority is involved with (in any role).
#
# "Curatorial content" means any of: a featuring (FeaturedContent), an approved
# Recommendation, or an incoming Aboutness (another work that is ABOUT the
# manifestation).
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
