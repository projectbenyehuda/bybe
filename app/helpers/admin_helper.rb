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
    descending = params[dir_param] == 'desc'
    arrow = ''
    arrow = descending ? ' ▼' : ' ▲' if active
    next_dir = active && !descending ? 'desc' : 'asc'
    query = request.query_parameters.merge(sort_param => key, dir_param => next_dir)
    link_to("#{label}#{arrow}", tag_moderation_path(query), class: 'sort-link')
  end
end
