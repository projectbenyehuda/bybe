# frozen_string_literal: true

# Link related to lexicon entry
class LexLink < ApplicationRecord
  belongs_to :item, polymorphic: true, inverse_of: :links

  validates :url, presence: true

  # Returns true if the link was checked and is inaccessible: either it returned
  # a 4xx/5xx status, or the host was unreachable (nil status after a check).
  # checked_at distinguishes "checked and dead" from "never checked".
  # Local/relative URLs are never considered broken — they are served by our
  # own application and cannot be checked via HTTP HEAD.
  # A link the checker could not get a verdict on (see #unverifiable?) is not broken:
  # we simply do not know, and an editor has to look at it.
  def broken?
    return false unless url.to_s.start_with?('http://', 'https://')
    return false if unverifiable?

    checked_at.present? && (http_status.nil? || http_status >= 400)
  end
end
