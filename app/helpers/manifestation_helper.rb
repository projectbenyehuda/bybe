module ManifestationHelper
  def options_from_images(record)
    # skip any non-image attachments that may have been accidentally uploaded
    record.images.select(&:variable?).map do |img|
      blob = img.blob
      filename = blob.filename.to_s
      content_tag(
        :option,
        filename,
        value: record.download_path(filename), # user-friendly URL
        data: {
          description: ' ', # when description is empty ddslick increases the height of the dropdown on each open
          imagesrc: url_for(img.variant(resize_to_fill: [150, nil])) # thumbnail
        }.merge(image_dimensions_data(blob))
      )
    end.join.html_safe
  end

  def image_dimensions_data(blob)
    blob.analyze unless blob.analyzed?

    width = blob.metadata['width']
    height = blob.metadata['height']

    {}.tap do |dims|
      dims[:width] = width if width.present?
      dims[:height] = height if height.present?
    end
  end

  private :image_dimensions_data

  def authorlist_decorator_by_sort_type(sort_type)
    case sort_type
    when /birth/
      return method(:author_birth_date_decorator)
    when /death/
      return method(:author_death_date_decorator)
    when /upl/
      return method(:browse_upload_date)
    else
      return method(:browse_null_decorator)
    end
  end

  def author_birth_date_decorator(item)
    thedate = item.person.present? ? item.person['birth_year'] : nil
    return " (#{thedate.nil? ? t(:unknown) : thedate})"
  end

  def author_death_date_decorator(item)
    thedate = item.person.present? ? item.person['death_year'] : nil
    return " (#{thedate.nil? ? t(:unknown) : thedate})"
  end

  def browse_upload_date(item)
    " (#{item.pby_publication_date&.to_date&.strftime('%d-%m-%Y')})"
  end

  def browse_null_decorator(item)
    ''
  end

  # Builds the path for a sibling next/prev navigation link in Manifestation#read, optionally
  # carrying forward the current parent collection (so the target page shows the same parent when the
  # work belongs to several collections) and the count of skipped placeholder items.
  def read_sibling_path(item, parent_collection_id = nil, skipped: 0)
    query = {}
    query[:skipped] = skipped if skipped.to_i.positive?
    query[:parent_collection_id] = parent_collection_id if parent_collection_id.present?
    base = default_link_by_class(item.class, item.id)
    query.empty? ? base : "#{base}?#{query.to_query}"
  end
end
