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

  def preloaded_author_aboutnesses(author)
    author.aboutnesses.preload(
      work: {
        involved_authorities: :authority,
        expressions: [:manifestations, { involved_authorities: :authority }]
      }
    )
  end
end
