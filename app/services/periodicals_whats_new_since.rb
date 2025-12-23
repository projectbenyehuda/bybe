# frozen_string_literal: true

# Service to fetch new periodical publications since a given timestamp grouped by authority
class PeriodicalsWhatsNewSince < ApplicationService
  def call(timestamp)
    authors = {}
    # Get all published manifestations that are new since the timestamp
    # and are contained in periodicals (have periodical_issue in parent chain)
    Manifestation.all_published.new_since(timestamp).includes(:expression, collection_items: :collection).find_each do |m|
      # Skip if not in a periodical
      next unless m.in_periodical?

      e = m.expression
      next if e.nil?

      w = e.work
      authority = e.translation ? m.translators.first : m.authors.first
      next if authority.nil?

      if authors[authority].nil?
        authors[authority] = {}
        authors[authority][:latest] = 0
      end
      authors[authority][w.genre] = [] if authors[authority][w.genre].nil?
      authors[authority][w.genre] << m
      authors[authority][:latest] = m.updated_at if m.updated_at > authors[authority][:latest]
    end
    authors
  end
end
