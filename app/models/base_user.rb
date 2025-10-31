# Model to represent all users of system: both authenticated and not-authenticated
# If user is authenticated we link this record to User model, otherwise we link it to session
class BaseUser < ApplicationRecord
  belongs_to :user, inverse_of: :base_user, optional: true

  has_many :bookmarks, inverse_of: :base_user, dependent: :destroy
  has_many :visits, class_name: 'Ahoy::Visit', foreign_key: :user_id # track visits, for donation campaigns etc.

  DEFAULT_FONT_SIZE = '2'
  EMAIL_FREQUENCY_OPTIONS = %w(unlimited daily weekly none).freeze

  # This record must be identified either by user_id or by session_id, but not by both
  validates_absence_of :session_id, if: -> { self.user_id.present? }
  validates_presence_of :session_id, if: -> { self.user_id.nil? }

  ### User Preferences
  property_set :preferences do
    property :fontsize, default: DEFAULT_FONT_SIZE
    # property :volunteer, default: 'false' # boolean  (another option - :protected => true)
    # property :activated, default: 'false' # boolean
    # property :suppress_anthology_intro, default: 'false'
    property :suppress_donation_banner, default: 0
    property :jump_to_bookmarks
    property :accepted_tag_policy, default: 'false'
    property :email_frequency, default: 'unlimited'
  end

  def get_preference(pref)
    Rails.cache.fetch(preference_cache_key(pref)) do
      preferences.send(pref)
    end
  end

  def set_preference(pref, value)
    preferences.set(pref => value)
    preferences.save!
    Rails.cache.write(preference_cache_key(pref), value)
  end

  private

  # Use this to store preference value in Rails cache
  def preference_cache_key(pref)
    "bu_#{id}_#{pref}"
  end
end
