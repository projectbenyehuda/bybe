# frozen_string_literal: true

class PeriodicalsController < ApplicationController
  def index
    @periodicals = Collection.includes(:collection_items).where(collection_type: 'periodical').order(:title) # TODO: what order would make sense?
    @periodicals_count = Rails.cache.fetch('periodicals_count', expires_in: 15.minutes) do
      Collection.where(collection_type: 'periodical').count
    end
    @popular_works = ManifestationsIndex.query(match: { in_periodical: true })
                                        .filter(range: { impressions_count: { gte: 1 } })
                                        .order(impressions_count: :desc)
                                        .limit(10)
    @periodicals_text_count = Rails.cache.fetch('periodicals_text_count', expires_in: 15.minutes) do
      ManifestationsIndex.query(match: { in_periodical: true }).count
    end
  end

  def show; end
end
