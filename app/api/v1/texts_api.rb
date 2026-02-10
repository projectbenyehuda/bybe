# frozen_string_literal: true

module V1
  # API to retrieve information about Texts (Manifestations)
  class TextsApi < V1::ApplicationApi
    # rubocop:disable Metrics/BlockLength
    PAGE_SIZE = 25

    helpers do
      params :text_params do
        optional :view, type: String, default: 'basic', values: %w(metadata basic enriched), desc: <<~DESC
          how much detail to return:
            `metadata` returns all metadata and download link;
            `basic` returns basic metadata and a download_link, and is the default;
            `enriched` returns all metadata as well as tags, recommendations, external links, and aboutnesses
        DESC

        optional :file_format, type: String, default: 'html', values: %w(html txt pdf epub mobi docx odt), desc: <<~DESC
          desired text format for download link:
            `html` for HTML,
            `txt` for plain text without any formatting,
            `pdf` for PDF,
            `epub` for EPUB,
            `mobi` for MOBI,
            `docx` for DOCX,
            `odt` for LibreOffice ODT'
        DESC

        optional :snippet, type: Boolean, default: false, desc: <<~DESC
          whether or not to include a plaintext snippet of the beginning of the text.
        DESC
      end
    end

    params do
      use :key_param
    end

    resources :texts do
      resource :batch do
        params do
          requires :ids,
                   type: [Integer],
                   length: { max: 25 },
                   allow_blank: false,
                   desc: 'array of text IDs to fetch',
                   documentation: { param_type: 'body' }
          use :text_params
        end
        desc 'retrieve a collection of texts by specified IDs'
        post do
          ids = params[:ids]
          records = ManifestationsIndex.find(ids)
          # If ids contains only single value, Chewy returns single object instead of array, so explicitely convert
          # it to single-element array
          if ids.size == 1
            records = [records]
          end
          # sorting result in same order as their ids are passed in parameter
          records.sort_by! { |rec| ids.find_index(rec.id) }
          present records,
                  with: V1::Entities::ManifestationIndex,
                  view: params[:view],
                  file_format: params[:file_format],
                  snippet: params[:snippet]
        end
      end

      route_param :id do
        desc 'returns meta-data and, optionally, the full text, of a textual work from the database' do
          success V1::Entities::ManifestationIndex
        end
        params do
          requires :id, type: Integer, desc: 'Text ID'
          use :text_params
        end
        get do
          record = ManifestationsIndex.find(params[:id])
          present record,
                  with: V1::Entities::ManifestationIndex,
                  view: params[:view],
                  file_format: params[:file_format],
                  snippet: params[:snippet]
        end
      end
    end

    resource :search do
      params do
        use :key_param
        use :text_params

        optional :sort_by,
                 type: String,
                 default: 'alphabetical',
                 values: SearchManifestations::SORTING_PROPERTIES.keys - [SearchManifestations::RELEVANCE_SORT_BY],
                 desc: 'desired ordering of result set (ignored if fulltext search is used)'
        optional :sort_dir,
                 type: String,
                 default: 'default',
                 values: SearchManifestations::DIRECTIONS,
                 desc: 'desired ordering direction (ignored if fulltext search is used)'
        optional :search_after,
                 default: nil,
                 type: [String],
                 desc: <<~DESC,
                   special param to fetch next page of results, to get first page skip it,
                   to get next page use value returned in `next_page_search_after` attribute of previous page response.
                   Must be an array with exactly 2 string values (sort field value and document ID).
                 DESC
                 documentation: {
                   param_type: 'body',
                   example: %w(sort_field_value 12345)
                 }
        optional :genres,
                 type: [String],
                 values: Work::GENRES,
                 desc: 'the broad field of humanities of a textual work in the database.',
                 documentation: { param_type: 'body' }
        optional :periods,
                 type: [String],
                 values: Expression.periods.keys,
                 desc: 'specifies what section of the rough timeline of Hebrew literature an object belongs to.'
        optional :intellectual_property_types,
                 type: [String],
                 values: Expression::PUBLIC_INTELLECTUAL_PROPERTY_TYPES,
                 desc: 'limit search to works with selected intellectual property types'
        optional :author_genders, type: [String], values: Person.genders.keys
        optional :translator_genders, type: [String], values: Person.genders.keys
        optional :title, type: String, desc: "a substring to match against a text's title"
        optional :author, type: String, desc: "a substring to match against the name(s) of a text's author(s)"
        optional :fulltext,
                 type: String,
                 desc: <<~DESC
                   a query string to match against the work's full text, title and authors list
                   (NOTE: if provided it will enforce result ordering by relevance).
                   You can use complex expressions here, as documented at
                   https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-simple-query-string-query.html#simple-query-string-syntax"
                 DESC
        optional :author_ids, type: [Integer]
        optional :original_language,
                 type: String,
                 desc: "ISO code of language, e.g. 'pl' for Polish, 'grc' for ancient Greek. " \
                       "Use magic constant 'xlat' to match all non-Hebrew languages"

        optional :uploaded_between,
                 type: JSON,
                 desc: 'pass an years interval json `{ from: min_year, to: max_year}` to get works uploaded to ' \
                       'the site at year min_year <= year <= max_year' do
          optional :from, type: Integer
          optional :to, type: Integer
        end
        optional :created_between,
                 type: JSON,
                 desc: 'pass an years interval json `{ from: min_year, to: max_year}` to get works created at year ' \
                       'min_year <= year <= max_year' do
          optional :from, type: Integer
          optional :to, type: Integer
        end
        optional :published_between,
                 type: JSON,
                 desc: 'pass an years interval json `{ from: min_year, to: max_year}` to get works published in ' \
                       'print at year min_year <= year <= max_year' do
          optional :from, type: Integer
          optional :to, type: Integer
        end
      end

      desc 'Query the site database for texts by a variety of parameters. All parameters are combined with a ' \
           'logical AND. Parameters accepting arrays allow a logical OR within that category.' do
        success V1::Entities::ManifestationsPage
      end
      post do
        filters = params.slice(*%w(
                                 genres
                                 periods
                                 intellectual_property_types
                                 author_genders
                                 translator_genders
                                 title
                                 author
                                 fulltext
                                 author_ids
                                 uploaded_between
                                 created_between
                                 published_between
                               ))

        orig_lang = params['original_language']
        if orig_lang.present?
          filters['original_languages'] = [orig_lang]
        end

        if filters['fulltext'].present?
          sort_by = 'relevance'
          sort_dir = 'desc'
        else
          sort_by = params[:sort_by]
          sort_dir = params[:sort_dir]
        end

        records = SearchManifestations.call(sort_by, sort_dir, filters)
        total_count = records.count

        search_after = params[:search_after]
        if search_after.present?
          # Validate search_after has exactly 2 elements (sort field value + document ID)
          if search_after.size != 2
            error!(
              'search_after must contain exactly 2 values (sort field value and document ID), ' \
              "got #{search_after.size}",
              400
            )
          end
          records = records.search_after(search_after)
        end

        records = records.limit(PAGE_SIZE).to_a

        if records.size == PAGE_SIZE
          last = records.last
          next_page_search_after = [
            last.send(SearchManifestations::SORTING_PROPERTIES[sort_by][:column])&.to_s,
            last.id.to_s
          ]
        else
          next_page_search_after = nil
        end

        model = {
          data: records,
          total_count: total_count,
          next_page_search_after: next_page_search_after
        }
        present model,
                with: V1::Entities::ManifestationsPage,
                view: params[:view],
                file_format: params[:file_format],
                snippet: params[:snippet]
      end
    end
    # rubocop:enable Metrics/BlockLength
  end
end
