# frozen_string_literal: true

module Ahoy
  # a class representing an event tracked by Ahoy
  class Event < ApplicationRecord
    include Ahoy::QueryMethods

    ALLOWED_NAMES = %w(
      view
      download
      page_view
      search
      clicked_tag
      donev_text_footban
      donev_banner
      donev_sidebox_homepage
      donev_menu
      donev_mobile_menu
      donev_top_bar
      donev_mobile_top_banner
      donev_mobile_top_banner_scrolled
      donev_footban
      donev_footban_mobile
      donev_footer
      donev_bannmsg
      donev_text_footban_mobile
      donev_sidebox
    ).freeze

    self.table_name = 'ahoy_events'

    # `format` is stored inside the JSON properties by Tracking#track_download, and unlike `id` and `type`
    # it has no virtual column, so we have to extract it explicitly when aggregating.
    FORMAT_EXPRESSION = Arel.sql("json_unquote(json_extract(properties, '$.format'))")

    belongs_to :visit
    belongs_to :user, optional: true

    # For some events we store record type and id in JSON properties, and for convenience we've added
    # two virtual columns `item_id` and `item_type` to table so we can use it to establish polymorphic relation
    belongs_to :item, optional: true, polymorphic: true

    validates :name, presence: true, inclusion: { in: ALLOWED_NAMES }

    # Aggregates download events in the given time range.
    # @return [Hash] mapping [format, item_type] pairs to the number of downloads.
    #   Events recorded before format tracking was introduced have a nil format.
    def self.download_counts_by_format(from, to)
      where(name: 'download', time: from..to)
        .group(FORMAT_EXPRESSION, :item_type)
        .count
    end
  end
end
