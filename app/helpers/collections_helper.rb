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

  # Browse page decorators - show different metadata based on sort type
  def browse_collection_decorator_by_sort_type(sort_type)
    case sort_type
    when /publ/
      method(:browse_collection_pub_date)
    when /popular/
      method(:browse_collection_popularity)
    else
      method(:browse_collection_type)
    end
  end

  def browse_collection_pub_date(collection)
    pub_year = collection.normalized_pub_year || collection.inception_year
    return " (#{pub_year || t(:unknown)})"
  end

  def browse_collection_popularity(collection)
    return " (#{collection.impressions_count} #{t(:views)})"
  end

  def browse_collection_type(collection)
    return " • #{t(collection.collection_type)}"
  end

  # Returns icon/badge for collection type
  def collection_type_icon(collection_type)
    case collection_type
    when 'volume'
      content_tag(:span, '📚', class: 'collection-type-icon', title: t(:volume))
    when 'periodical'
      content_tag(:span, '📰', class: 'collection-type-icon', title: t(:periodical))
    when 'series'
      content_tag(:span, '📑', class: 'collection-type-icon', title: t(:series))
    when 'other'
      content_tag(:span, '📁', class: 'collection-type-icon', title: t(:other))
    else
      ''
    end
  end

  # Format involved authorities for display (first 3 with roles)
  def format_collection_authorities(collection)
    authorities = collection.involved_authorities.preload(:authority).first(3)
    return '' if authorities.empty?

    formatted = authorities.map do |ia|
      "#{ia.authority.name} (#{t(ia.role)})"
    end
    formatted.join(', ')
  end

  # Converts absolute URLs pointing to the provided base_url into relative paths.
  # Preserves query strings and fragments.
  #
  # @param base_url [String] The base URL to match against (e.g., "https://example.com")
  # @param html_string [String] The HTML content to process
  # @return [String] The modified HTML with relative URLs
  def convert_internal_links_to_relative(base_url, html_string)
    return html_string if html_string.blank? || base_url.blank?

    # Normalize the base URL (remove trailing slash) and parse
    normalized_base = base_url.chomp('/')
    begin
      base_uri = URI.parse(normalized_base)
    rescue URI::InvalidURIError
      # If the base URL itself is malformed, return the original HTML unchanged
      return html_string
    end

    # Cheap pre-check: if there are no anchor tags or no occurrence of the base URL / host,
    # skip Nokogiri parsing entirely for performance on large HTML fragments.
    host_str = base_uri.host.to_s
    has_anchor_tags = html_string.include?('<a')
    has_base_or_host = html_string.include?(normalized_base) ||
                       (!host_str.empty? && html_string.include?(host_str))
    return html_string unless has_anchor_tags && has_base_or_host

    # Parse the HTML
    doc = Nokogiri::HTML.fragment(html_string)

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
          # Normalize empty paths to '/' to avoid href=""
          relative_path = href_uri.path.presence || '/'
          relative_path += "?#{href_uri.query}" if href_uri.query.present?
          relative_path += "##{href_uri.fragment}" if href_uri.fragment.present?

          link['href'] = relative_path
          # Remove target attribute since internal links should not open in new tabs
          link.remove_attribute('target')
        end
      rescue URI::InvalidURIError
        # Skip malformed URIs
        next
      end
    end

    doc.to_html
  end
end
