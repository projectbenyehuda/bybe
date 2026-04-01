# frozen_string_literal: true

# Maps legacy URLs (e.g. /bialik/bia001.html) to current targets (Manifestation, Authority, etc.)
class LegacyUrl < ApplicationRecord
  belongs_to :target, polymorphic: true, optional: true

  validates :from_url, presence: true, uniqueness: true
  validates :from_url, format: { with: %r{\A/} }

  # Normalize URL: ensure leading slash, strip trailing slash (except root)
  before_validation :normalize_from_url

  scope :ordered, -> { order(:from_url) }

  # Look up a LegacyUrl by an incoming request path, applying normalization:
  #   - Ensure leading slash
  #   - Strip trailing slash
  #   - Treat /dir/index.html as /dir
  def self.find_for_url(path)
    canonical = normalize_url(path)
    find_by(from_url: canonical)
  end

  # Same normalization used for lookup — also used by routing constraint.
  def self.exists_for_url?(path)
    exists?(from_url: normalize_url(path))
  end

  # Returns the redirect destination URL for the target, or nil if unsupported.
  # Manifestation and Authority are handled explicitly; other targets are
  # resolved generically via #url_path if defined, so future types (e.g.
  # FeaturedContent) can opt in by implementing that method.
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
    else
      target.url_path if target.respond_to?(:url_path)
    end
  end

  def self.normalize_url(path)
    path = "/#{path}" unless path.start_with?('/')
    # Strip /index.html or /index suffix from directory-style URLs
    path = path.sub(%r{/index\.html\z}, '').sub(%r{/index\z}, '')
    # Strip trailing slash (except root "/")
    path.chomp!('/') if path.length > 1
    path
  end
  private_class_method :normalize_url

  private

  def normalize_from_url
    return if from_url.blank?

    self.from_url = self.class.send(:normalize_url, from_url)
  end
end
