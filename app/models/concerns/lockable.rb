# frozen_string_literal: true

# To prevent simultaneous editing of same entity by two users this concern implements locking logic.
# Before editing user needs to obtain lock on record and release lock after editing is done.
# Locks also should expire after given timeout period
module Lockable
  extend ActiveSupport::Concern

  LOCK_TIMEOUT_IN_SECONDS = 60 * 15 # 15 minutes

  included do
    belongs_to :locked_by_user, class_name: 'User', optional: true
    belongs_to :last_editor, class_name: 'User', optional: true

    validates :locked_at, presence: true, if: -> { locked_by_user.present? }
    validates :locked_at, absence: true, unless: -> { locked_by_user.present? }
  end

  def locked?
    locked_at.present? && locked_at > LOCK_TIMEOUT_IN_SECONDS.seconds.ago
  end

  def obtain_lock?(user)
    return false if locked? && locked_by_user_id != user.id

    # To avoid excessive updates we only refresh lock if more than 10 seconds passed since previous lock refresh
    if locked_at.nil? || locked_at < 10.seconds.ago
      # we deliberately skip validations here
      update_columns(locked_at: Time.zone.now, locked_by_user_id: user.id, last_editor_id: user.id)
    end

    return true
  end

  def release_lock!
    update_columns(locked_at: nil, locked_by_user_id: nil) # we deliberately skip validations here
  end
end
