# frozen_string_literal: true

module CollectionsHelper
  def url_for_collection_item(collitem)
    return nil if collitem.item.nil?
    return nil unless collitem.public?

    # Sub-volume/sub-issue collections (type 'series' or 'periodical_issue') are not the focus of a
    # Collection#show view, so their titles are shown but not clickable within the containing view.
    item = collitem.item
    return nil if item.is_a?(Collection) && (item.series? || item.periodical_issue?)

    url_for(item)
  end

  # Path for a Collection search result. Sub-volume/sub-issue collections (type 'series') aren't the
  # focus of a Collection#show view, so their result links point to the volume/issue-level parent's
  # show page plus an anchor leading to the sub-collection within that view. Non-series results (and
  # orphan series with no volume/issue ancestor) link to their own show page as usual.
  def collection_search_result_path(result, query)
    if result.collection_type == 'series'
      collection = Collection.find_by(id: result.id)
      parent = collection&.parent_volume_or_isssue
      return collection_path(parent.id, q: query, anchor: "collection_#{result.id}") if parent.present?
    end

    collection_path(result.id, q: query)
  end

  # Path for the "up link" shown in Manifestation#read navigation for a containing collection.
  # Sub-volume/sub-issue collections (type 'series' or 'periodical_issue') aren't the focus of a
  # Collection#show view, so the link points to the volume/issue-level parent's show page plus an
  # anchor leading to the sub-collection within that view. Collections that are themselves a
  # volume/issue (or have no such ancestor) link to their own show page as usual.
  def collection_up_link_path(collection)
    if collection.series? || collection.periodical_issue?
      parent = collection.parent_volume_or_isssue
      return collection_path(parent.id, anchor: "collection_#{collection.id}") if parent.present?
    end

    collection_path(collection)
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
    return " (#{collection.impressions_count} #{t(:num_views)})"
  end

  def browse_collection_type(collection)
    return " • #{textify_collection_type(collection.collection_type)}"
  end

  # Returns icon/badge for collection type
  def collection_type_icon(collection_type)
    case collection_type
    when 'volume'
      content_tag(:span, '📚', class: 'collection-type-icon', title: textify_collection_type(:volume))
    when 'periodical'
      content_tag(:span, '📰', class: 'collection-type-icon', title: textify_collection_type(:periodical))
    when 'series'
      content_tag(:span, '📑', class: 'collection-type-icon', title: textify_collection_type(:series))
    when 'other'
      content_tag(:span, '📁', class: 'collection-type-icon', title: textify_collection_type(:other))
    else
      ''
    end
  end

  # Format involved authorities for display (first 3 with roles)
  def format_collection_authorities(collection)
    # Handle both Chewy documents and ActiveRecord models
    if collection.respond_to?(:involved_authorities_string)
      # Chewy document - use pre-computed string
      collection.involved_authorities_string
    elsif collection.respond_to?(:involved_authorities)
      # ActiveRecord model - load from associations
      authorities = collection.involved_authorities.preload(:authority).first(3)
      return '' if authorities.empty?

      formatted = authorities.map do |ia|
        "#{ia.authority.name} (#{t(ia.role)})"
      end
      formatted.join(', ')
    else
      ''
    end
  end

  # Converts absolute URLs pointing to the provided base_url into relative paths.
  # Preserves query strings and fragments.
  # When current_path is provided, anchor links whose path matches current_path and that
  # include a fragment have their target="_blank" removed so they don't open in a new tab.
  # Query strings are preserved in the href but are not considered for this comparison.
  #
  # @param base_url [String] The base URL to match against (e.g., "https://example.com")
  # @param html_string [String] The HTML content to process
  # @param current_path [String, nil] The current page path (e.g., "/collections/123")
  # @return [String] The modified HTML with relative URLs
  def convert_internal_links_to_relative(base_url, html_string, current_path = nil)
    return html_string if html_string.blank? || base_url.blank?

    # Normalize the base URL (remove trailing slash) and parse
    normalized_base = base_url.chomp('/')
    begin
      base_uri = Addressable::URI.parse(normalized_base)
    rescue Addressable::URI::InvalidURIError
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
        href_uri = Addressable::URI.parse(href)

        # Check if it's an absolute URL pointing to our base URL
        if href_uri.absolute? && href_uri.host == base_uri.host && href_uri.scheme == base_uri.scheme
          # Convert to relative path (include path, query, and fragment)
          # Normalize empty paths to '/' to avoid href=""
          relative_path = href_uri.path.presence || '/'
          relative_path += "?#{href_uri.query}" if href_uri.query.present?
          relative_path += "##{href_uri.fragment}" if href_uri.fragment.present?

          link['href'] = relative_path

          # Remove target="_blank" for same-page anchor links (path matches current page),
          # but only when target is _blank — preserve named frame targets.
          normalized_href_path = href_uri.path.presence || '/'
          if current_path.present? && normalized_href_path == current_path &&
             href_uri.fragment.present? && link['target'].to_s.casecmp('_blank').zero?
            link.remove_attribute('target')
          end
        end
      rescue Addressable::URI::InvalidURIError
        # Skip malformed URIs
        next
      end
    end

    doc.to_html
  end
end
