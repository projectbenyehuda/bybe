# frozen_string_literal: true

# Service to fetch new publications since a given timestamp grouped by authority
class WhatsNewSince < ApplicationService
  def call(timestamp)
    authors = {}
    Manifestation.all_published.new_since(timestamp).includes(:expression).find_each do |m|
      e = m.expression
      next if e.nil? # shouldn't happen

      w = e.work
      authority = e.translation ? m.translators.first : m.authors.first # TODO: more nuance
      next if authority.nil? # shouldn't happen, but might in a dev. env.

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
