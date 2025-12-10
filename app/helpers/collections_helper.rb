module CollectionsHelper
  def url_for_collection_item(collitem)
    collitem.item.nil? ? nil : url_for(collitem.item)
  end

  def render_external_link_item(link, collection_id)
    content_tag(:div, class: 'external_link_item', id: "external_link_#{link.id}",
                      style: 'margin-bottom: 10px; padding: 5px; background-color: white;') do
      concat(content_tag(:span, class: 'link_info') do
        concat(link_to(link.description, link.url, target: :_blank))
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
end
