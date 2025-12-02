# frozen_string_literal: true

# Service to build a newsfeed of recent news items and publications
# Currently only shows newly created manifestations, but can be extended to include youtube videos, blog posts, etc.
class Newsfeed < ApplicationService
  include Rails.application.routes.url_helpers

  def call
    # read at most the last 5 persistent news items (Facebook posts, announcements)
    unsorted_news_items = NewsItem.last(5)

    WhatsNewSince.call(1.month.ago).each do |person, pubs| # add newly-published works
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
    # cached_youtube_videos.each do |title, desc, id, thumbnail_url, relevance| # add latest videos
    #  unsorted_news_items << NewsItem.from_youtube(title, desc, youtube_url_from_id(id), thumbnail_url, relevance)
    # end
    # TODO: add latest blog posts
    return unsorted_news_items.sort_by(&:relevance).reverse # sort by descending relevance
  end

  # def cached_youtube_videos
  #   Rails.cache.fetch('cached_youtube', expires_in: 24.hours) do # memoize
  #     # return latest_youtube_videos # commented out due to quote problem, and caching failure yet TBD
  #     []
  #   end
  # end
  #
  # def latest_youtube_videos
  #   ret = []
  #   begin
  #     channel = Yt::Channel.new id: Rails.configuration.constants['youtube_channel_id']
  #     vids = channel.videos
  #     max = vids.count > 5 ? 5 : vids.count
  #     i = 0
  #     vids.each  do |v|
  #       break if i >= max
  #
  #       ret << [v.title, v.description, v.id, v.thumbnail_url, v.published_at]
  #       i += 1
  #     end
  #   rescue StandardError
  #     puts 'No network?'
  #   end
  #   return ret
  # end
  #
  # def youtube_url_from_id(id)
  #   return 'https://www.youtube.com/watch?v=' + id
  # end
end
