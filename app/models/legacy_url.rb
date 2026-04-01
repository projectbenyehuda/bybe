# frozen_string_literal: true

# Maps legacy URLs (e.g. /bialik/bia001.html) to current targets (Manifestation, Authority, etc.)
class LegacyUrl < ApplicationRecord
  belongs_to :target, polymorphic: true, optional: true

  validates :from_url, presence: true, uniqueness: true
  validates :from_url, format: { with: %r{\A/} }

  # Normalize URL: ensure leading slash, strip trailing slash (except root)
  before_validation :normalize_from_url

  scope :ordered, -> { order(:from_url) }

  def target_url
    return nil unless target

    case target
    when Manifestation
      Rails.application.routes.url_helpers.url_for(
        controller: :manifestation, action: :read, id: target.id, only_path: true
      )
    when Authority
      Rails.application.routes.url_helpers.url_for(
        controller: :authors, action: :toc, id: target.id, only_path: true
      )
    end
  end

  private

  def normalize_from_url
    return if from_url.blank?

    from_url.prepend('/') unless from_url.start_with?('/')
    from_url.chomp!('/') if from_url.length > 1
  end
end
