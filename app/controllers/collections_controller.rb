# frozen_string_literal: true

# Controller to work with Collections.
# Most of the actions require editor's permissions
class CollectionsController < ApplicationController
  include Tracking
  include BybeUtils
  include KwicConcordanceConcern

  before_action :require_editor, except: %i(show download print kwic kwic_download pby_volumes)
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

    dl = @collection.fresh_downloadable_for(format)
    if dl.nil?
      prep_for_show # TODO
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
        dl = MakeFreshDownloadable.call(params[:format], filename, html, @collection, austr)
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
    prep_for_show
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
                   ci.genre, counter[:value], ci, 0, []]
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
                   nesting_level, parent_authorities]
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
        @htmls << [ci.title, ci.involved_authorities,
                   html.present? ? footnotes_noncer(html, counter[:value]) : '',
                   false, ci.genre, counter[:value], ci, nesting_level, parent_authorities]
        counter[:value] += 1
      end
    end
  end

  protected

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
