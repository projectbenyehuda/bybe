# frozen_string_literal: true

class PeriodicalsController < ApplicationController
  def index
    @periodicals = Collection.includes(:collection_items).where(collection_type: 'periodical').order(:title) # TODO: what order would make sense?
    @periodicals_count = Rails.cache.fetch('periodicals_count', expires_in: 60.minutes) do
      Collection.where(collection_type: 'periodical').count
    end
    @popular_works = ManifestationsIndex.query(match: { in_periodical: true })
                                        .filter(range: { impressions_count: { gte: 1 } })
                                        .order(impressions_count: :desc)
                                        .limit(10)
    @newest_works = ManifestationsIndex.query(match: { in_periodical: true })
                                       .order(pby_publication_date: :desc)
                                       .limit(10)
    @periodicals_text_count = Rails.cache.fetch('periodicals_text_count', expires_in: 15.minutes) do
      ManifestationsIndex.query(match: { in_periodical: true }).count
    end
    @random_periodical = @periodicals.sample # pick a random periodical to feature out of the already-fetched @periodicals
    @periodicals_whatsnew = Rails.cache.fetch('periodicals_whatsnew', expires_in: 2.hours) do
      PeriodicalsWhatsNewSince.call(1.month.ago)
    end
    @periodical_authors_in_genre = cached_periodical_authors_in_genre
    @periodical_works_by_genre = Manifestation.cached_periodical_work_counts_by_genre
    @periodical_first_covers = build_periodical_first_covers(@periodicals)
  end

  def show; end

  private

  def build_periodical_first_covers(periodicals)
    issue_ids_by_periodical = {}
    periodicals.each do |p|
      ids = p.collection_items.select { |ci| ci.item_type == 'Collection' }.map(&:item_id)
      issue_ids_by_periodical[p.id] = ids
    end

    all_issue_ids = issue_ids_by_periodical.values.flatten.uniq
    return {} if all_issue_ids.empty?

    all_issues = Collection.where(id: all_issue_ids).to_a
    ActiveRecord::Associations::Preloader.new(
      records: all_issues,
      associations: { cover_image_attachment: :blob }
    ).call
    issues_by_id = all_issues.index_by(&:id)

    periodicals.each_with_object({}) do |p, hash|
      ids = issue_ids_by_periodical[p.id]
      hash[p.id] = ids.lazy.map { |id| issues_by_id[id] }.find { |i| i&.cover_image&.attached? }
    end
  end
end
