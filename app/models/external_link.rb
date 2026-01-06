class ExternalLink < ApplicationRecord
  belongs_to :linkable, polymorphic: true

  # Validations
  validates :url, presence: true
  validate :url_must_have_safe_scheme

  enum :linktype, {
    wikipedia: 0,
    blog: 1,
    youtube: 2,
    other: 3,
    publisher_site: 4,
    dedicated_site: 5,
    audio: 6,
    gnazim: 7,
    source_text: 8
  }, prefix: true

  enum :status, {
    approved: 0,
    submitted: 1,
    rejected: 2,
    escalated: 3
  }, prefix: true

  def self.sidebar_link_types # excluding the publisher_site link, which is used in the main area for texts published by permission
    return %i(wikipedia dedicated_site blog youtube audio other gnazim)
  end

  private

  def url_must_have_safe_scheme
    return if url.blank?

    begin
      uri = URI.parse(url.to_s)
      unless %w[http https].include?(uri.scheme&.downcase)
        errors.add(:url, :invalid_scheme, message: 'must use http or https protocol')
      end
    rescue URI::InvalidURIError
      errors.add(:url, :invalid_uri, message: 'is not a valid URL')
    end
  end
end
