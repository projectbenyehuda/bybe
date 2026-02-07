# frozen_string_literal: true

module CollectionsHelper
  def url_for_collection_item(collitem)
    collitem.item.nil? ? nil : url_for(collitem.item)
  end

  def render_external_link_item(link, collection_id)
    content_tag(:div, class: 'external_link_item', id: "external_link_#{link.id}",
                      style: 'margin-bottom: 10px; padding: 5px; background-color: white;') do
      concat(content_tag(:span, class: 'link_info') do
        concat(link_to(link.description, link.url, target: :_blank, rel: :noopener))
        concat(" (#{t(link.linktype)})")
      end)
      concat(content_tag(:button, t(:delete), class: 'delete_external_link by-button-v02 by-button-secondary-v02',
                                              type: 'button',
                                              data: { link_id: link.id, collection_id: collection_id },
                                              style: 'margin-left: 10px; float: right;'))
    end
  end

  # Converts absolute URLs pointing to the provided base_url into relative paths.
  # Preserves query strings and fragments.
  #
  # @param base_url [String] The base URL to match against (e.g., "https://example.com")
  # @param html_string [String] The HTML content to process
  # @return [String] The modified HTML with relative URLs
  def convert_internal_links_to_relative(base_url, html_string)
    return html_string if html_string.blank? || base_url.blank?

    # Parse the HTML
    doc = Nokogiri::HTML.fragment(html_string)

    # Normalize the base URL (remove trailing slash)
    normalized_base = base_url.chomp('/')
    base_uri = URI.parse(normalized_base)

    # Find all anchor tags with href attributes
    doc.css('a[href]').each do |link|
      href = link['href']
      next if href.blank?

      begin
        # Parse the href URL
        href_uri = URI.parse(href)

        # Check if it's an absolute URL pointing to our base URL
        if href_uri.absolute? && href_uri.host == base_uri.host && href_uri.scheme == base_uri.scheme
          # Convert to relative path (include path, query, and fragment)
          relative_path = href_uri.path
          relative_path += "?#{href_uri.query}" if href_uri.query.present?
          relative_path += "##{href_uri.fragment}" if href_uri.fragment.present?

          link['href'] = relative_path
        end
      rescue URI::InvalidURIError
        # Skip malformed URIs
        next
      end
    end

    doc.to_html
  end
end
