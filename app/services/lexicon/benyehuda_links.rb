# frozen_string_literal: true

module Lexicon
  # Resolves a link to benyehuda.org into the Authority it points at.
  #
  # Emulates what HtmlFileController#render_by_legacy_url does, supporting both forms:
  # - numeric ID: https://benyehuda.org/author/1234
  # - slug:       https://benyehuda.org/shats (looked up via HtmlDir)
  module BenyehudaLinks
    HOST_PATTERN = %r{\Ahttps?://(?:www\.)?benyehuda\.org}i

    module_function

    # Returns the Authority the given URL points at, or nil if the URL is not a
    # benyehuda.org author link, or no matching Authority exists.
    def authority_for(url)
      url = url.to_s
      return nil unless url.match?(HOST_PATTERN)

      begin
        path = URI.parse(url).path
      rescue URI::InvalidURIError
        return nil
      end

      return nil if path.blank?

      authority_from_path(path)
    end

    def authority_from_path(path)
      # Numeric ID: /author/1234 or /author/1234/
      if (match = path.match(%r{\A/author/(\d+)/?\z}))
        return Authority.find_by(id: match[1].to_i)
      end

      # Non-numeric slug: /shats or /shats/index
      # Extract first non-numeric path segment and look up in HtmlDir.
      # HtmlDir belongs_to :person (Person model), which has_one :authority.
      segment = path.split('/').compact_blank.first
      return nil if segment.blank?
      return nil if segment.match?(/\A\d+\z/)

      HtmlDir.find_by(path: segment)&.person&.authority
    end
  end
end
