module CollectionsHelper
  def url_for_collection_item(collitem)
    collitem.item.nil? ? nil : polymorphic_path(collitem.item)
  end
end
