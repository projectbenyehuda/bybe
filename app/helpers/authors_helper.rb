module AuthorsHelper
  def authors_label_by_gender_filter(gender_filter, total)
    if gender_filter.blank?
      return t(:x_authors_mixed_gender, x: total)
    elsif gender_filter == ['female']
      return t(:x_authors_female, x: total)
    elsif gender_filter == ['male']
      return t(:x_authors_male, x: total)
    else
      return t(:x_authors_mixed_gender, x: total)
    end # TODO: support more genders
  end

  def browse_item_decorator_by_sort_type(sort_type)
    case sort_type
    when /publ/
      return method(:browse_pub_date)
    when /cre/
      return method(:browse_creation_date)
    when /upl/
      return method(:browse_upload_date)
    else
      return method(:browse_null_decorator)
    end
  end
  def browse_pub_date(item)
    thedate = item.orig_publication_date
    return " (#{thedate.nil? ? t(:unknown) : thedate.to_date.strftime('%d-%m-%Y')})"
  end
  def browse_creation_date(item)
    thedate = item.creation_date
    return " (#{thedate.nil? ? t(:unknown) : thedate.to_date.strftime('%d-%m-%Y')})"
  end
  def browse_upload_date(item)
    return " (#{item.pby_publication_date.strftime('%d-%m-%Y')})"
  end
  def browse_null_decorator(item)
    return ''
  end

  def manifestation_label(manifestation, role, authority_id)
    label = manifestation.title
    case role.to_s
    when 'author'
      if manifestation.authors.size > 1 || manifestation.authors.pluck(:id) != [authority_id]
        # when the author is not the only author or not the author in a volume he is generally the author of
        # (e.g. someone else's preface to this author's book)
        label += " / #{authorities_string(manifestation, :author)}"
      end
      unless manifestation.translators.empty?
        label += " #{t(:translated_by)} #{authorities_string(manifestation, :translator)}"
      end
    when 'translator'
      label += " / #{authorities_string(manifestation, :author)}"
      if manifestation.translators.size > 1
        label += " / #{authorities_string(manifestation, :translator)}"
      end
    else # editors, illustrators, etc.
      label += " / #{manifestation.author_string}"
      if manifestation.involved_authorities_by_role(role).size > 1
        label += " #{I18n.t("toc_by_role.made_by.#{role}")} #{authorities_string(manifestation, role)}"
      end
    end

    label
  end

  # Returns string, containing comma-separated list of names of authorities linked to given text with given role
  # @param manifestation
  # @param role
  # @param exclude_authority_id - if provided given authority will be excluded from the list
  def authorities_string(manifestation, role, exclude_authority_id: nil)
    manifestation.involved_authorities_by_role(role)
                 .reject { |au| au.id == exclude_authority_id }
                 .map(&:name)
                 .sort
                 .join(', ')
  end

  # Single-line list of the authorities involved in a work, for the works list's summary cards:
  # "name (role), name (role)", roles in the usual presentation order.
  #
  # A role whose only holder is the authority whose page this is contributes nothing the page
  # doesn't already say, so it is dropped. That is the same omission #manifestation_label makes in
  # each of its branches: the sole author on their own page, the sole translator on theirs, and so
  # on.
  # @param manifestation
  # @param authority_id - the authority whose page the list is shown on
  def compact_authorities_line(manifestation, authority_id)
    by_role = manifestation.involved_authorities.group_by(&:role)
    by_named_role = InvolvedAuthority::ROLES_PRESENTATION_ORDER.filter_map do |role|
      authorities = by_role[role].to_a.map(&:authority).uniq.sort_by(&:name)
      next if authorities.empty? || authorities.map(&:id) == [authority_id]

      authorities.map { |au| "#{au.name} (#{textify_role(role, au.gender)})" }.join(', ')
    end
    by_named_role.join(', ')
  end

  def preloaded_author_aboutnesses(author)
    author.aboutnesses.preload(
      work: {
        involved_authorities: :authority,
        expressions: [:manifestations, { involved_authorities: :authority }]
      }
    )
  end

  # Count total manifestations across multiple TOC nodes
  def count_toc_nodes_manifestations(nodes, role, authority_id, involved_on_collection_level)
    nodes.sum { |node| node.count_manifestations(role, authority_id, involved_on_collection_level) }
  end

  # Splits an authority's top-level TOC nodes into the three sections a role's TOC block is made
  # of. Single source of truth for "which sections does this role have", shared by the TOC body
  # (authors/_toc_by_role), the in-page navbar (shared/_newtoc_navbar) and the controller's count
  # calculation, so the three cannot drift apart on which roles they show.
  #
  # Note this is deliberately about node PRESENCE, not manifestation counts: an unpublished
  # manifestation is still rendered (unlinked) in the TOC while counting as 0, so a role can
  # legitimately have sections to show and a total count of zero.
  def toc_role_sections(top_nodes, role, authority_id)
    collection_level = top_nodes.select { |node| node.visible?(role, authority_id, true) }
                                .sort_by(&:sort_term)
    work_level = top_nodes.select { |node| node.visible?(role, authority_id, false) }
                          .sort_by(&:sort_term)
    uncollected = work_level.detect { |node| node.collection.uncollected? }
    work_level -= [uncollected] if uncollected.present?

    { collection_level: collection_level, work_level: work_level, uncollected: uncollected }
  end

  # Whether a role has any TOC content at all, i.e. whether its heading should be rendered
  def toc_role_present?(sections)
    sections[:collection_level].present? || sections[:work_level].present? ||
      sections[:uncollected].present?
  end
end
