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
end
