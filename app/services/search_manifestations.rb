# frozen_string_literal: true

class SearchManifestations < ApplicationService
  DIRECTIONS = %w(default asc desc).freeze

  RELEVANCE_SORT_BY = 'relevance'

  SORTING_PROPERTIES = {
    'alphabetical' => { default_dir: 'asc', column: :sort_title },
    'popularity' => { default_dir: 'desc', column: :impressions_count },
    'publication_date' => { default_dir: 'asc', column: :orig_publication_date },
    'creation_date' => { default_dir: 'asc', column: :creation_date },
    'upload_date' => { default_dir: 'desc', column: :pby_publication_date },
    RELEVANCE_SORT_BY => { default_dir: 'desc', column: :_score }
  }.freeze

  def call(sort_by, sort_dir, filters)
    filter = []

    add_simple_filter(filter, :genre, filters['genres'])
    add_simple_filter(filter, :period, filters['periods'])
    add_simple_filter(filter, :intellectual_property, filters['intellectual_property_types'])
    add_simple_filter(filter, :author_gender, filters['author_genders'])
    add_simple_filter(filter, :translator_gender, filters['translator_genders'])
    add_simple_filter(filter, :author_ids, filters['author_ids'])

    original_languages = filters['original_languages']
    if original_languages.present?
      # xlat - is a magic constant meaning 'any language except hebrew'
      if original_languages.include?('xlat')
        # if all translated and hebrew are requested together this means no filtering
        unless original_languages.include?('he')
          filter << { bool: { must_not: { terms: { orig_lang: ['he'] } } } }
        end
      else
        filter << { terms: { orig_lang: original_languages } }
      end
    end

    tags = filters['tags']
    if tags.present?
      filter << { terms: { tags: tags } }
    end

    add_date_range(filter, :pby_publication_date, filters['uploaded_between'])
    add_date_range(filter, :creation_date, filters['created_between'])
    add_date_range(filter, :orig_publication_date, filters['published_between'])

    author = filters['author']
    if author.present?
      filter << { match: { author_string: { query: author, operator: 'and' } } }
    end

    title = filters['title']
    if title.present?
      filter << { match_phrase: { title: title } } # TODO: also search in alternate_titles
    end

    if filter.empty? # only include primary works in all-works query
      filter << { term: { primary: true } }
    end

    result = ManifestationsIndex.filter(filter)

    fulltext = filters['fulltext']
    if fulltext.present?
      # if fulltext query is performed we also request highlight text, to return snippet matching query
      result = result.query(simple_query_string: {
                              fields: %i(title author_string alternate_titles fulltext),
                              query: fulltext,
                              default_operator: :and
                            })
                     .highlight(fields: { fulltext: {} }, max_analyzed_offset: 1_000_000)
    end

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

  def add_date_range(list, field, range_param)
    return if range_param.nil? || range_param.empty?
    range_expr = {}
    year = range_param['from']
    # Greater than or equal to first day of from-year
    # Use Time.new to match the system's local timezone, which is how timestamps are typically created
    # This ensures consistency with records created via Time.parse or default Rails timestamps
    range_expr['gte'] = Time.new(year, 1, 1, 0, 0, 0).iso8601 if year.present?
    year = range_param['to']
    # Less than first day of year next to to-year
    range_expr['lt'] = Time.new(year + 1, 1, 1, 0, 0, 0).iso8601 if year.present?
    unless range_expr.empty?
      list << { range: { field => range_expr } }
    end
  end
end
