# frozen_string_literal: true

# Removes a duplicated trailing anchor from a URL before it is saved.
#
# When an editor replaces a dead link with an Internet Archive snapshot, the original URL's
# fragment often ends up in the archived URL twice, e.g.
#   https://web.archive.org/web/20200101/http://example.com/page#section#section
# Browsers tolerate this, but URI.parse rejects the second '#', so
# Lexicon::CheckExternalLinks#parse_uri cannot parse the URL and the freshly-fixed link is
# immediately reported broken again.
module TrimsDuplicateUrlAnchor
  extend ActiveSupport::Concern

  # 'http://example.com/p#sec#sec' -> 'http://example.com/p#sec'.
  # Only repetitions of one and the same anchor are trimmed: differing fragments are a URL we
  # do not understand, and guessing which one the editor meant would be worse than leaving it.
  # Exposed on the module (not just as an instance method) so the one-off cleanup task for URLs
  # stored before this fix -- rake fix_lexicon_duplicate_url_anchors -- shares the same rule.
  def self.trim(url)
    return url if url.blank?

    base, *anchors = url.split('#')
    return url if anchors.size < 2 || anchors.uniq.size > 1

    "#{base}##{anchors.first}"
  end

  private

  def trim_duplicate_url_anchor(url)
    TrimsDuplicateUrlAnchor.trim(url)
  end
end
