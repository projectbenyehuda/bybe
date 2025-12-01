# frozen_string_literal: true

# Service to build a newsfeed of recent news items and publications
class Newsfeed < ApplicationService
  include Rails.application.routes.url_helpers

  def call
    unsorted_news_items = NewsItem.last(5) # read at most the last 5 persistent news items

    WhatsNewSince.call(1.month.ago).each do |person, pubs|
      # Extract manifestations from pubs hash (skip :latest key)
      manifestations = pubs.values.select { |v| v.is_a?(Array) }.flatten
      unsorted_news_items << NewsItem.from_publications(
        person,
        TextifyNewPubs.call(manifestations),
        pubs,
        authority_path(person.id),
        person.profile_image.url(:thumb)
      )
    end

    unsorted_news_items.sort_by(&:relevance).reverse
  end
end
