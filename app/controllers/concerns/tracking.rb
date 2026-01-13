# frozen_string_literal: true

# Logic to track record view events
module Tracking
  extend ActiveSupport::Concern

  SPIDERS = [
    'msnbot',
    'yahoo! slurp',
    'googlebot',
    'bingbot',
    'duckduckbot',
    'baiduspider',
    'yandexbot',
    'semrushbot'
  ].freeze

  def spider?
    return @spider unless @spider.nil?

    user_agent = request.user_agent&.downcase
    @spider = user_agent.present? && SPIDERS.any? { |s| user_agent.include?(s) }
  end

  # View event is used to track show or print events on object
  # @param record object being viewed (Manifestation, Authority, etc)
  def track_view(record)
    return if spider?

    props = object_properties_for_tracking(record)
    track_event('view', props)
    record.increment!(:impressions_count) # we simply increase impressions_count here

    # we only update Chewy index every 10 views to reduce performance impact
    return unless record.impressions_count % 10 == 0

    # increment! method does not trigger Chewy index update so we do it explicitly here
    # for performance purpose we specify only single field to be updated
    index_class = case record.class.name
                  when 'Collection' then CollectionsIndex
                  when 'Manifestation' then ManifestationsIndex
                  when 'Authority' then AuthoritiesIndex
                  end

    index_class&.send(:import, record, import_fields: [:impressions_count])
  end

  # Download event should be triggered when we download file associated with object
  # @param object being downloaded (Manifestation, Collection, etc)
  def track_download(record, format)
    props = object_properties_for_tracking(record)
    props[:format] = format
    track_event('download', props)
  end

  # Page view event is used to track generic page views
  # `properties` hash will contain controller and action values to identify which page was viewed
  def track_page_view
    track_event('page_view')
  end

  # Generic method used to track random events
  # @param event Event name to be tracked (Ensure it is included in Ahoy::Events::ALLOWED_NAMES)
  # @param properties Hash object containing additional properties to associate with event
  # NOTE: this method always adds to `properties` action and controller names, so no need to add them explicitely
  def track_event(event, properties = {})
    return if spider?
    raise "Unknown event: #{event}" unless Ahoy::Event::ALLOWED_NAMES.include?(event)

    properties[:controller] = controller_name
    properties[:action] = action_name

    ahoy.track(event, properties)
  end

  def object_properties_for_tracking(object)
    raise 'Object must be an ActiveRecord object' unless object.is_a?(ActiveRecord::Base)

    {
      type: object.class.name,
      id: object.id
    }
  end
end
