# frozen_string_literal: true

# Shared helper methods for working with PaperTrail versions
module PaperTrailHelpers
  extend ActiveSupport::Concern

  private

  # Safe deserialization of PaperTrail version objects
  def deserialize_version_object(object_yaml)
    # Use safe_load with allowed classes for ActiveRecord objects
    Psych.safe_load(
      object_yaml,
      permitted_classes: [
        ActiveSupport::TimeWithZone,
        ActiveSupport::TimeZone,
        Time,
        Symbol
      ],
      aliases: true
    )
  end

  # Check if markdown field was changed in a version
  def markdown_changed_in_version?(version)
    # If object_changes is available, check if markdown key exists
    return version.changeset&.key?('markdown') || false if version.object_changes.present?

    # Fallback: Check by comparing deserialized objects
    # First version (create event) always has markdown
    return true if version.event == 'create'

    # For updates without object_changes, check if object contains markdown
    return false if version.object.blank?

    begin
      old_attrs = deserialize_version_object(version.object)
      old_attrs.key?('markdown')
    rescue StandardError
      false
    end
  end
end
