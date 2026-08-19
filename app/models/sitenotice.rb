class Sitenotice < ApplicationRecord
  CACHE_KEY = 'sitenotices_v2'.freeze # v2: cached value is now [[id, body], ...] rather than a joined string

  enum :status, { disabled: 0, enabled: 1 }

  validates_presence_of :body, :fromdate, :todate

  scope :in_effect, -> { enabled.where('fromdate <= ? and todate >= ?', Time.zone.today, Time.zone.today) }

  # [[id, body], ...] of the notices currently in effect, memoized across requests
  def self.in_effect_notices
    Rails.cache.fetch(CACHE_KEY, expires_in: 2.hours) do
      in_effect.pluck(:id, :body)
    end
  end

  def self.clear_cache
    Rails.cache.delete(CACHE_KEY)
  end
end
