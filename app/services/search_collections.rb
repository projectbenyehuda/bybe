# frozen_string_literal: true

class SearchCollections < ApplicationService
  DIRECTIONS = %w(default asc desc).freeze

  SORTING_PROPERTIES = {
    'alphabetical' => { default_dir: 'asc', column: :sort_title },
    'popularity' => { default_dir: 'desc', column: :impressions_count },
    'publication_date' => { default_dir: 'asc', column: :normalized_pub_year }
  }.freeze

  def call(sort_by, sort_dir, filters)
    filter = []

    add_simple_filter(filter, :collection_type, filters['collection_types'])
    add_simple_filter(filter, :involved_authority_ids, filters['authority_ids'])

    tags = filters['tags']
    if tags.present?
      filter << { terms: { tags: tags } }
    end

    # Publication date range - uses normalized_pub_year or inception_year
    add_pub_date_range(filter, filters['publication_date_between'])

    title = filters['title']
    if title.present?
      filter << { match_phrase: { title: title } }
    end

    result = CollectionsIndex.filter(filter)

    sort_props = SORTING_PROPERTIES[sort_by]
    if sort_dir == 'default'
      sort_dir = sort_props[:default_dir]
    end
    # We additionally sort by id to order records with equal values in main sorting column
    result.order([{ sort_props[:column] => sort_dir }, { id: sort_dir }])
  end

  private

  def add_simple_filter(list, field, value)
    return if value.blank?
    list << { terms: { field => value } }
  end

  def add_pub_date_range(list, range_param)
    return if range_param.nil? || range_param.empty?

    range_expr = {}
    from_year = range_param['from']
    to_year = range_param['to']

    range_expr['gte'] = from_year if from_year.present?
    range_expr['lte'] = to_year if to_year.present?

    unless range_expr.empty?
      # Use bool query with should to check both normalized_pub_year and inception_year
      list << {
        bool: {
          should: [
            { range: { normalized_pub_year: range_expr } },
            { range: { inception_year: range_expr } }
          ],
          minimum_should_match: 1
        }
      }
    end
  end
end
