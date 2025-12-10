# frozen_string_literal: true

# Controller to work with Collections.
# Most of the actions require editor's permissions
class CollectionsController < ApplicationController
  include Tracking
  include BybeUtils
  include KwicConcordanceConcern
  include FilteringAndPaginationConcern

  before_action :require_editor, except: %i(browse show download print kwic kwic_download pby_volumes)
  before_action :set_collection, only: %i(show update destroy)

  # GET /collections/1 or /collections/1.json
  def show
    data = FetchCollection.call(@collection)

    if data.all_manifestations.size == 1
      redirect_to manifestation_path(data.all_manifestations.first)
    end

    @header_partial = 'shared/collection_top'
    @scrollspy_target = 'chapternav'
    @colls_traversed = [@collection.id]
    @print_url = url_for(action: :print, collection_id: @collection.id)
    @pagetype = :collection
    @taggings = @collection.taggings

    @included_recs = @collection.included_recommendations.count
    @total_recs = @collection.recommendations.count + @included_recs
    @credits = render_to_string(partial: 'collections/credits', locals: { collection: @collection })
    @page_title = "#{@collection.title} - #{t(:default_page_title)}"
    prep_for_show
    track_view(@collection)
    prep_user_content(:collection) # user anthologies, bookmarks
  end

  # GET /pby_volumes
  def pby_volumes
    @pby_volumes = Collection.pby_volumes.order(:title).load
    @pby_volumes_count = @pby_volumes.size
    @page_title = "#{t(:pby_volumes)} - #{t(:default_page_title)}"
  end

  # GET /collections - Browse all collections with filters
  def browse
    @pagetype = :collections
    @collections_list_title = t(:collections_list) unless @collections_list_title.present?
    if valid_query?
      es_prep_collection
      @maxdate = Time.zone.today.strftime('%Y')
      @header_partial = 'collections/browse_top'

      render :browse
    else
      head :bad_request
    end
  end

  # GET /collections/1/periodical_issues
  def periodical_issues
    @collection = Collection.find(params[:collection_id])
    render json: { issues: @collection.coll_items.where(collection_type: 'periodical_issue') }
  end

  def add_periodical_issue
    @collection = Collection.find(params[:collection_id])
    @issue = Collection.create!(title: params[:title], sort_title: params[:title], collection_type: 'periodical_issue')
    @collection.involved_authorities.each do |ia| # copy authorities from parent collection as defaults
      @issue.involved_authorities.create!(authority_id: ia.authority.id, role: ia.role)
    end
    @collection.append_item(@issue)
  end

  # POST /collections/create_periodical_with_issue
  def create_periodical_with_issue
    periodical_title = params.require(:periodical_title)
    issue_title = params.require(:issue_title)

    # Validate that titles are not blank
    if periodical_title.blank? || issue_title.blank?
      render json: { success: false, error: I18n.t('ingestible.both_titles_required') },
             status: :unprocessable_content
      return
    end

    error_response = nil
    ActiveRecord::Base.transaction do
      # Create the periodical collection
      @periodical = Collection.create(
        title: periodical_title,
        sort_title: periodical_title,
        collection_type: 'periodical'
      )

      unless @periodical.persisted?
        error_response = { success: false, error: @periodical.errors.full_messages.join(', ') }
        raise ActiveRecord::Rollback
      end

      # Create the first issue within the periodical
      @issue = Collection.create(
        title: issue_title,
        sort_title: issue_title,
        collection_type: 'periodical_issue'
      )

      unless @issue.persisted?
        error_response = { success: false, error: @issue.errors.full_messages.join(', ') }
        raise ActiveRecord::Rollback
      end

      # Add the issue to the periodical
      @periodical.append_item(@issue)
    end

    if error_response
      render json: error_response, status: :unprocessable_content
      return
    end

    render json: {
      success: true,
      periodical_id: @periodical.id,
      periodical_title: @periodical.title,
      issue_id: @issue.id,
      issue_title: @issue.title
    }
  rescue ActionController::ParameterMissing => e
    render json: { success: false, error: e.message }, status: :unprocessable_content
  rescue StandardError => e
    Rails.logger.error("Failed to create periodical with issue: #{e.message}")
    render json: { success: false, error: I18n.t('ingestible.creation_failed') },
           status: :unprocessable_content
  end

  # GET /collections/1/download
  def download
    @collection = Collection.find(params[:collection_id])

    if @collection.suppress_download_and_print
      flash[:error] = t(:download_disabled)
      redirect_to @collection
      return
    end
    format = params[:format]
    unless Downloadable.doctypes.include?(format)
      flash[:error] = t(:unrecognized_format)
      redirect_to @collection
      return
    end

    # Check if we're doing selective download
    manifestation_ids = params[:manifestation_ids]
    download_scope = params[:download_scope] || 'full'
    is_partial = manifestation_ids.present? && download_scope == 'partial'

    # For selective downloads, we can't use cached downloadables
    dl = is_partial ? nil : @collection.fresh_downloadable_for(format)

    if dl.nil?
      prep_for_show # TODO

      # Filter @htmls if selective download
      if is_partial
        selected_ids = manifestation_ids.map(&:to_i)
        @htmls = @htmls.select do |_title, _ias, _html, _is_curated, _genre, _i, ci, _nesting_level, _parent_authorities,
                                   _title_footnote|
          ci.item_type == 'Manifestation' && selected_ids.include?(ci.item_id)
        end
      end

      filename = "#{@collection.title.gsub(/[^0-9א-תA-Za-z.\-]/, '_')}.#{format}"

      if format == 'kwic'
        # Trigger async job for KWIC concordance generation
        GenerateKwicConcordanceJob.perform_async('Collection', @collection.id)
        flash[:notice] = t(:kwic_being_generated)
        redirect_to @collection
        return
      else
        # TODO: implement ias
        html = <<~WRAPPER
          <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
          "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
          <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="he" lang="he" dir="rtl">
          <head><meta http-equiv="Content-Type" content="text/html; charset=utf-8" /></head>
          <body dir='rtl'><div dir="rtl" align="right">
          <div style="font-size:300%; font-weight: bold;">#{@collection.title}</div>
          #{@htmls.map { |h| downloadable_html(h) }.join("\n")}

          <hr />
          #{I18n.t(:download_footer_html, url: url_for(@collection))}
          </div></body></html>
        WRAPPER
        austr = textify_authorities_and_roles(@collection.involved_authorities)

        # For partial downloads, generate file on-the-fly without caching
        if is_partial
          track_download(@collection, format)
          send_generated_file(format, filename, html, austr)
          return
        else
          dl = MakeFreshDownloadable.call(params[:format], filename, html, @collection, austr)
        end
      end
    end

    track_download(@collection, format)
    redirect_to rails_blob_url(dl.stored_file, disposition: :attachment)
  end

  # GET /collections/1/print
  def print
    @print = true
    @collection = Collection.find(params[:collection_id])

    if @collection.suppress_download_and_print
      flash[:error] = t(:print_disabled)
      redirect_to @collection
      return
    end

    # Check if we're doing selective print
    manifestation_ids = params[:manifestation_ids]
    print_scope = params[:print_scope] || 'full'

    prep_for_show

    # Filter @htmls if selective print
    if manifestation_ids.present? && print_scope == 'partial'
      selected_ids = manifestation_ids.map(&:to_i)
      @htmls = @htmls.select do |_title, _ias, _html, _is_curated, _genre, _i, ci, _nesting_level, _parent_authorities,
                                 _title_footnote|
        ci.item_type == 'Manifestation' && selected_ids.include?(ci.item_id)
      end
    end

    track_view(@collection)
    @footer_url = url_for(@collection)
  end

  # POST /collections or /collections.json
  def create
    @collection = Collection.new(collection_params)

    if @collection.save
      if params['authority'].present? && params['authority']['id'].present? && params['authority']['role'].present?
        @collection.involved_authorities.create!(authority_id: params['authority']['id'].to_i,
                                                 role: params['authority']['role'])
      end
      # redirect_to collection_url(@collection), notice: t(:created_successfully)
      render json: @collection
    else
      head :unprocessable_content
    end
  end

  # PATCH/PUT /collections/1 or /collections/1.json
  def update
    if @collection.update(collection_params)
      respond_to do |format|
        format.html { redirect_to collection_url(@collection), notice: t(:updated_successfully) }
        format.js
      end
    else
      head :unprocessable_content
    end
  end

  # DELETE /collections/1 or /collections/1.json
  def destroy
    @destroyed_id = @collection.id
    @collection.destroy

    respond_to do |format|
      format.html { redirect_to collections_url, notice: t(:deleted_successfully) }
      format.js
    end
  end

  def manage
    @collection = Collection.find(params[:collection_id])
    head :forbidden if @collection.collection_type == 'uncollected' # refuse to edit uncollected collections
  end

  def add_external_link
    @collection = Collection.find(params[:collection_id])
    @link = @collection.external_links.create!(
      url: params[:url],
      linktype: params[:linktype],
      description: params[:description],
      status: :approved
    )

    respond_to do |format|
      format.js
    end
  rescue StandardError => e
    @error = e.message
    respond_to do |format|
      format.js { render js: "alert('#{I18n.t(:error)}: ' + #{e.message.to_json});" }
    end
  end

  def remove_external_link
    @collection = Collection.find(params[:collection_id])
    @link = @collection.external_links.find(params[:link_id])
    @link.destroy!

    head :ok
  rescue StandardError => e
    render plain: e.message, status: :unprocessable_content
  end

  # Display KWIC concordance browser for a collection
  def kwic
    @collection = Collection.find(params[:collection_id])

    unless @collection.flatten_items.any? { |ci| ci.item_type == 'Manifestation' && ci.item.present? }
      flash[:error] = t(:empty_collection)
      redirect_to @collection
      return
    end

    @page_title = "#{t(:kwic_concordance)} - #{@collection.title} - #{t(:default_page_title)}"
    @pagetype = :collection
    @entity = @collection
    @entity_type = 'Collection'

    # Use fresh downloadable mechanism to ensure KWIC downloadable exists
    dl = ensure_kwic_downloadable_exists(@collection)

    # Check if concordance is being generated asynchronously
    if dl.nil?
      flash[:notice] = t(:kwic_being_generated)
      redirect_to @collection
      return
    end

    # Parse concordance data from the stored downloadable
    if dl&.stored_file&.attached?
      kwic_text = dl.stored_file.download.force_encoding('UTF-8')
      @concordance_data = ParseKwicConcordance.call(kwic_text)

      # Enrich instances with manifestation IDs for context fetching
      @collection.flatten_items.each do |ci|
        next if ci.item.nil? || ci.item_type != 'Manifestation'

        @concordance_data.each do |entry|
          entry[:instances].each do |instance|
            if instance[:label] == ci.title
              instance[:manifestation_id] = ci.item.id
            end
          end
        end
      end
    else
      # This shouldn't happen since ensure_kwic_downloadable_exists returns nil for async generation
      flash[:error] = t(:error_generating_concordance)
      redirect_to @collection
      return
    end

    # Pagination setup
    @per_page = (params[:per_page] || 10).to_i
    @per_page = 10 unless [10, 25, 50].include?(@per_page)

    # Filtering
    @filter_text = params[:filter].to_s.strip
    if @filter_text.present?
      @concordance_data = @concordance_data.select do |entry|
        entry[:token].include?(@filter_text)
      end
    end

    # Sorting
    @sort_by = params[:sort].to_s.strip
    @sort_by = 'alphabetical' unless %w(alphabetical frequency).include?(@sort_by)
    @concordance_data = sort_concordance_data(@concordance_data, 'frequency') if @sort_by == 'frequency' # data is already alphabetical by default

    @total_entries = @concordance_data.length
    @page = (params[:page] || 1).to_i
    @total_pages = (@total_entries.to_f / @per_page).ceil
    @page = [@page, @total_pages].min if @total_pages > 0
    @page = 1 if @page < 1

    offset = (@page - 1) * @per_page
    @concordance_entries = @concordance_data[offset, @per_page] || []

    # Create a lookup hash for collection items to avoid N+1 queries in the view
    @collection_items_by_label = {}
    @collection.flatten_items.each do |ci|
      @collection_items_by_label[ci.title] = ci if ci.item_type == 'Manifestation'
    end
  end

  # Get extended context for a paragraph (AJAX endpoint)
  def kwic_context
    manifestation_id = params[:manifestation_id].to_i
    paragraph_num = params[:paragraph].to_i

    manifestation = Manifestation.find(manifestation_id)
    context = get_extended_context(manifestation, paragraph_num)

    render json: {
      prev: context[:prev],
      current: context[:current],
      next: context[:next]
    }
  end

  # Download filtered or full KWIC concordance for collection
  def kwic_download
    @collection = Collection.find(params[:collection_id])

    # Generate concordance data from all manifestations in collection
    labelled_texts = []
    @collection.flatten_items.each do |ci|
      next if ci.item.nil? || ci.item_type != 'Manifestation'

      labelled_texts << {
        label: ci.title,
        buffer: ci.item.to_plaintext
      }
    end

    concordance_data = kwic_concordance(labelled_texts)

    # Apply filter if present
    filter_text = params[:filter].to_s.strip
    if filter_text.present?
      concordance_data = concordance_data.select do |entry|
        entry[:token].include?(filter_text)
      end
    end

    # Generate text file
    kwic_text = format_concordance_as_text(concordance_data)

    filename = "#{@collection.title.gsub(/[^0-9א-תA-Za-z.\-]/, '_')}_kwic.txt"

    send_data kwic_text,
              filename: filename,
              type: 'text/plain; charset=utf-8',
              disposition: 'attachment'
  end

  def es_prep_collection
    @sort_dir = 'default'
    if params[:sort_by].present?
      @sort = params[:sort_by].dup
      @sort_by = params[:sort_by].sub(/_(a|de)sc$/, '')
      @sort_dir = ::Regexp.last_match(0)[1..-1] unless ::Regexp.last_match(0).nil?
    else
      # use alphabetical sorting by default
      @sort = 'alphabetical_asc'
      @sort_by = 'alphabetical'
      @sort_dir = 'asc'
    end

    filter = build_es_filter_from_filters

    # This param means that we're getting previous page
    # so we should revert sort ordering while quering ElasticSearch index
    @reverse = params[:reverse] == 'true'
    sort_dir_to_use = if @reverse
                        @sort_dir == 'asc' ? 'desc' : 'asc'
                      else
                        @sort_dir
                      end

    @collection = SearchCollections.call(@sort_by, sort_dir_to_use, filter)

    # Adding filtering by first letter
    @to_letter = params['to_letter']
    if @to_letter.present?
      @collection = @collection.filter({ prefix: { sort_title: @to_letter } })
      @filters << [I18n.t(:title_starts_with_x, x: @to_letter), :to_letter, :text]
    end

    @collections = paginate(@collection)
  end

  def build_es_filter_from_filters
    ret = {}
    @filters = []

    # collection types
    @collection_types = params['ckb_collection_types'] unless @collection_types.present?
    if @collection_types.present?
      ret['collection_types'] = @collection_types
      @filters += @collection_types.map { |x| [I18n.t(x), "collection_type_#{x}", :checkbox] }
    end

    # tags by tag_id
    tag_ids_array = params['tag_ids'].split(',').map(&:to_i) unless @tag_ids.present? || params['tag_ids'].blank?
    if tag_ids_array.present?
      tag_data = Tag.where(id: tag_ids_array).pluck(:id, :name)
      ret['tags'] = tag_data.map(&:last)
      @filters += tag_data.map { |x| [x.last, "tag_#{x.first}", :checkbox] }
      @tag_ids = tag_ids_array.join(',') # Keep as comma-separated string for the form
    end

    # publication date range
    @fromdate = params['fromdate'].to_i if params['fromdate'].present?
    @todate = params['todate'].to_i if params['todate'].present?
    range_expr = {}

    if @fromdate.present?
      range_expr['from'] = @fromdate
      @filters << ["#{I18n.t(:publication_date)} #{I18n.t(:fromdate)}: #{@fromdate}", :fromdate, :text]
    end

    if @todate.present?
      range_expr['to'] = @todate
      @filters << ["#{I18n.t(:publication_date)} #{I18n.t(:todate)}: #{@todate}", :todate, :text]
    end

    ret['publication_date_between'] = range_expr unless range_expr.empty?

    # authority ids - multi-select authorities
    if params['authorities'].present?
      authority_ids = params['authorities'].split(',').map(&:to_i)
      ret['authority_ids'] = authority_ids
      @authorities = authority_ids
      @authorities_names = params['authorities_names']
      @filters << [I18n.t(:authorities_xx, xx: @authorities_names), 'authorities', :authoritylist]
    end

    # title search
    @search_input = params['search_input']
    if @search_input.present?
      ret['title'] = @search_input
      @filters << [I18n.t(:title_x, x: @search_input), :search_input, :text]
    end

    return ret
  end

  def prepare_totals(collection)
    standard_aggregations = {
      collection_types: { terms: { field: 'collection_type' } },
      # We may need to increase `size` threshold in future if number of authorities exceeds 2000
      authority_ids: { terms: { field: 'involved_authority_ids', size: 2000 } }
    }

    collection = collection.aggregations(standard_aggregations)

    @collection_type_facet = buckets_to_totals_hash(collection.aggs['collection_types']['buckets'])

    # Preparing list of authorities to show in multiselect modal on collections browse page
    if collection.filter.present?
      authority_ids = collection.aggs['authority_ids']['buckets'].pluck('key')
      @authorities_list = Authority.where(id: authority_ids)
    else
      @authorities_list = Authority.all
    end
    @authorities_list = @authorities_list.select(:id, :name).sort_by(&:name)
  end

  def get_sort_column(sort_by)
    SearchCollections::SORTING_PROPERTIES[sort_by][:column]
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_collection
    @collection = Collection.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def collection_params
    params.require(:collection).permit(:title, :sort_title, :subtitle, :issn, :collection_type, :inception,
                                       :inception_year, :publisher_line, :pub_year, :publication_id, :toc_id, :toc_strategy, :alternate_titles, :description)
  end

  # Generate and send file directly without caching (for selective downloads)
  def send_generated_file(format, filename, html, author_string)
    # Convert images to absolute URLs for formats that need them
    html = images_to_absolute_url(html) unless %w[epub mobi].include?(format)

    case format
    when 'pdf'
      html.gsub!(/<img src=.*?active_storage.*?>/) { |match| "<div style=\"width:209mm\">#{match}</div>" }
      html.sub!('</head>',
                '<style>html, body {width: 20cm !important;} p{max-width: 20cm;} div {max-width:20cm;} img {max-width: 100%;}</style></head>')
      pdfname = HtmlFile.pdf_from_any_html(html)
      # Read file content before deleting
      pdf_content = File.binread(pdfname)
      File.delete(pdfname)
      send_data pdf_content, filename: filename, type: 'application/pdf', disposition: 'attachment'
    when 'docx'
      content = PandocRuby.convert(html, M: 'dir=rtl', from: :html, to: :docx).force_encoding('UTF-8')
      send_data content, filename: filename, type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    when 'odt'
      content = PandocRuby.convert(html, M: 'dir=rtl', from: :html, to: :odt).force_encoding('UTF-8')
      send_data content, filename: filename, type: 'application/vnd.oasis.opendocument.text'
    when 'html'
      send_data html, filename: filename, type: 'text/html; charset=utf-8'
    when 'txt'
      txt = html2txt(html)
      txt.gsub!("\n", "\r\n") # windows linebreaks
      send_data txt, filename: filename, type: 'text/plain; charset=utf-8'
    when 'epub'
      epubname = make_epub_from_single_html(html, @collection, author_string)
      # Read file content before deleting
      epub_content = File.binread(epubname)
      File.delete(epubname)
      send_data epub_content, filename: filename, type: 'application/epub+zip', disposition: 'attachment'
    when 'mobi'
      epubname = make_epub_from_single_html(html, @collection, author_string)
      mobiname = epubname[epubname.rindex('/') + 1..-6] + '.mobi'
      `kindlegen #{epubname} -c1 -o #{mobiname}`
      mobiname = epubname[0..-6] + '.mobi'
      # Read file content before deleting
      mobi_content = File.binread(mobiname)
      File.delete(epubname)
      File.delete(mobiname)
      send_data mobi_content, filename: filename, type: 'application/x-mobipocket-ebook', disposition: 'attachment'
    else
      raise ArgumentError, "Unrecognized format: #{format}"
    end
  end

  def images_to_absolute_url(buf)
    buf.gsub('<img src="/rails/active_storage',
             "<img src=\"#{Rails.application.routes.url_helpers.root_url}/rails/active_storage")
  end

  def prep_for_show
    @htmls = []
    counter = { value: 1 } # Use hash to maintain reference across recursive calls
    parent_authorities = @collection.involved_authorities.map { |ia| [ia.authority_id, ia.role] }

    if @collection.periodical? || @collection.volume_series? # we don't want to show an entire periodical's or volume series' run in a single Web page; instead, we show the complete TOC of all issues/volumes
      @collection.collection_items.each do |ci|
        next unless ci.item.present? && ci.item_type == 'Collection'
        # For periodicals, show only periodical_issue items; for volume_series, show only volume items
        next unless (@collection.periodical? && ci.item.collection_type == 'periodical_issue') ||
                    (@collection.volume_series? && ci.item.collection_type == 'volume')

        html = ci.item.toc_html
        @htmls << [ci.item.title, ci.involved_authorities_by_role('editor'), html, false,
                   ci.genre, counter[:value], ci, 0, [], nil] # nil for footnote (TOC items don't have footnotes)
        counter[:value] += 1
      end
    else
      build_htmls_recursively(@collection.collection_items, parent_authorities, 0, counter)
    end
    @collection_total_items = @collection.collection_items.reject { |ci| ci.paratext }.count
    @collection_minus_placeholders = @collection.collection_items.reject do |ci|
      !ci.public? || ci.paratext.present? || ci.alt_title.present?
    end.count
    @authority_for_image = if @collection.authors.present?
                             @collection.authors.first
                           elsif @collection.translators.present?
                             @collection.translators.first
                           elsif @collection.editors.present?
                             @collection.editors.first
                           else
                             Authority.new(name: '')
                           end
  end

  def build_htmls_recursively(collection_items, parent_authorities, nesting_level, counter)
    collection_items.each do |ci|
      next if ci.item.present? && ci.item_type == 'Manifestation' && ci.item.status != 'published' # deleted or unpublished manifestations

      if ci.item.present? && ci.item_type == 'Collection'
        # This is a sub-collection - render it with full detail
        sub_collection = ci.item

        # Filter out authorities that are exactly the same (ID and role) as parent
        all_authorities = ci.involved_authorities
        filtered_authorities = all_authorities.reject do |ia|
          parent_authorities.include?([ia.authority_id, ia.role])
        end

        # Add the sub-collection header (without HTML content - will be rendered differently in view)
        @htmls << [ci.title, filtered_authorities, nil, false, ci.genre, counter[:value], ci,
                   nesting_level, parent_authorities, nil] # nil for footnote
        counter[:value] += 1

        # Build the new parent_authorities list for children of this sub-collection
        # It's the combination of current parent_authorities plus this collection's authorities
        new_parent_authorities = parent_authorities + all_authorities.map { |ia| [ia.authority_id, ia.role] }
        new_parent_authorities.uniq!

        # Recursively process the sub-collection's items
        build_htmls_recursively(sub_collection.collection_items, new_parent_authorities, nesting_level + 1, counter)
      else
        # This is a manifestation or other item
        html = ci.to_html

        # Extract first footnote reference if this is a manifestation
        title_footnote = nil
        if ci.item.present? && ci.item_type == 'Manifestation'
          footnote_result = ExtractFirstFootnoteReference.call(ci.item.markdown, html)
          html = footnote_result[:cleaned_html]
          title_footnote = footnote_result[:footnote_html]
          # Salt the footnote link to match the salted body
          title_footnote = salt_footnote_link(title_footnote, counter[:value]) if title_footnote.present?
        end

        @htmls << [ci.title, ci.involved_authorities,
                   html.present? ? footnotes_noncer(html, counter[:value]) : '',
                   false, ci.genre, counter[:value], ci, nesting_level, parent_authorities, title_footnote]
        counter[:value] += 1
      end
    end
  end

  protected

  def valid_query?
    return true unless params[:to_letter].present? && (params[:to_letter].any_hebrew? == false)
  end

  def downloadable_html(h)
    title, ias, html, = h
    out = "<h1>#{title}</h1>\n"

    # Add involved authorities (plain text, no links for downloads)
    if ias.present?
      InvolvedAuthority::ROLES_PRESENTATION_ORDER.each do |role|
        ras = ias.select { |ia| ia.role == role }
        next if ras.empty?

        role_text = I18n.t(role, scope: 'involved_authority.abstract_roles')
        names = ras.map { |ra| ra.authority.name }.join(', ')
        out += "<h3>#{role_text}: #{names}</h3>\n"
      end
    end

    out += html if html.present?
    out.force_encoding('UTF-8')
  end
end
