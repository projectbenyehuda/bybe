module AdminHelper
  INTELLECTUAL_PROPERTIES_ID_TO_TEXT = Expression.intellectual_properties.to_h do |code, id|
    [id, I18n.t(code, scope: 'intellectual_property')]
  end

  def textify_intellectual_property_id(id)
    INTELLECTUAL_PROPERTIES_ID_TO_TEXT[id]
  end

  # Header link that sorts a tag moderation list by +key+; +list+ is :tags or :taggings.
  # Clicking the active column toggles direction. Other params (e.g. tag_id, the other list's sort) are kept.
  def sort_link(label, key, list)
    sort_param = :"#{list}_sort"
    dir_param = :"#{list}_dir"
    active = params[sort_param] == key
    next_dir = active && params[dir_param] != 'desc' ? 'desc' : 'asc'
    arrow = active ? (params[dir_param] == 'desc' ? ' ▼' : ' ▲') : ''
    link_to("#{label}#{arrow}", tag_moderation_path(request.query_parameters.merge(sort_param => key, dir_param => next_dir)),
            class: 'sort-link')
  end
end
