# frozen_string_literal: true

# Controller to work with Collections.
# Most of the actions require editor's permissions
class CollectionsController < ApplicationController
  include Tracking
  include BybeUtils
  include KwicConcordanceConcern

  before_action :require_editor, except: %i(show download print)
  before_action :set_collection, only: %i(show edit update destroy drag_item)

  # GET /collections or /collections.json
  def index
    @collections = Collection.all
  end

  # GET /collections/1 or /collections/1.json
  def show
    unless @collection.has_multiple_manifestations?
      ci = @collection.flatten_items.select { |x| x.item_type == 'Manifestation' }.first
      if ci.nil?
        flash[:error] = t(:no_such_item)
        redirect_to '/'
      else
        redirect_to manifestation_path(ci.item.id)
      end
      return
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
        # Generate KWIC concordance for collection
        labelled_texts = []
        @collection.flatten_items.each do |ci|
          next if ci.item.nil? || ci.item_type != 'Manifestation'

          labelled_texts << {
            label: ci.title,
            buffer: ci.item.to_plaintext
          }
        end
        kwic_text = GenerateKwicConcordance.call(labelled_texts)
        austr = textify_authorities_and_roles(@collection.involved_authorities)
        dl = MakeFreshDownloadable.call(params[:format], filename, '', @collection, austr, kwic_text: kwic_text)
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

  # GET /collections/new
  def new
    @collection = Collection.new
  end

  # GET /collections/1/edit
  def edit; end

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

  # POST /collections/1/drag_item
  def drag_item
    # zero-based indexes of item in the list
    old_index = params.fetch(:old_index).to_i
    new_index = params.fetch(:new_index).to_i

    Collection.transaction do
      items = @collection.collection_items.order(:seqno).to_a
      item_to_move = items.delete_at(old_index)
      items.insert(new_index, item_to_move)

      items.each_with_index do |ci, index|
        ci.update!(seqno: index + 1) unless ci.seqno == index + 1
      end
    end
    head :ok
  end

  # POST /collections/1/transplant_item
  def transplant_item
    @collection = Collection.find(params[:collection_id])
    @dest_coll = Collection.find(params[:dest_coll_id].to_i)
    @src_coll = Collection.find(params[:src_coll_id].to_i)
    @old_item_id = params[:item_id].to_i
    @item = CollectionItem.find(@old_item_id)
    if @dest_coll.nil? || @src_coll.nil? || @item.nil?
      flash[:error] = t(:no_such_item)
      head :not_found
      return
    end
    ActiveRecord::Base.transaction do
      @new_item_id = @dest_coll.insert_item_at(@item, params[:new_pos].to_i)
      @src_coll.remove_item(@old_item_id)
    end
    head :ok
  end

  def manage
    @collection = Collection.find(params[:collection_id])
    head :forbidden if @collection.collection_type == 'uncollected' # refuse to edit uncollected collections
  end

  # Display KWIC concordance browser for a collection
  def kwic
    @collection = Collection.find(params[:collection_id])
    
    unless @collection.has_multiple_manifestations?
      flash[:error] = t(:no_such_item)
      redirect_to @collection
      return
    end

    @page_title = "#{t(:kwic_concordance)} - #{@collection.title} - #{t(:default_page_title)}"
    @pagetype = :collection
    @entity = @collection
    @entity_type = 'Collection'

    # Generate concordance data from all manifestations in collection
    labelled_texts = []
    @collection.flatten_items.each do |ci|
      next if ci.item.nil? || ci.item_type != 'Manifestation'

      labelled_texts << {
        label: ci.title,
        buffer: ci.item.to_plaintext,
        item_id: ci.item.id,
        item_type: 'Manifestation'
      }
    end
    
    @concordance_data = kwic_concordance(labelled_texts)

    # Pagination setup
    @per_page = (params[:per_page] || 25).to_i
    @per_page = 25 unless [25, 50, 100].include?(@per_page)
    
    # Filtering
    @filter_text = params[:filter].to_s.strip
    if @filter_text.present?
      @concordance_data = @concordance_data.select do |entry|
        entry[:token].include?(@filter_text)
      end
    end

    @total_entries = @concordance_data.length
    @page = (params[:page] || 1).to_i
    @total_pages = (@total_entries.to_f / @per_page).ceil
    @page = [@page, @total_pages].min if @total_pages > 0
    @page = 1 if @page < 1

    offset = (@page - 1) * @per_page
    @concordance_entries = @concordance_data[offset, @per_page] || []

    prep_user_content(:collection)
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
                                       :inception_year, :publisher_line, :pub_year, :publication_id, :toc_id, :toc_strategy, :alternate_titles)
  end

  def prep_for_show
    @htmls = []
    i = 1
    if @collection.periodical? # we don't want to show an entire periodical's run in a single Web page; instead, we show the complete TOC of all issues
      @collection.collection_items.each do |ci|
        next unless ci.item.present? && ci.item_type == 'Collection' && ci.item.collection_type == 'periodical_issue'

        html = ci.item.toc_html
        @htmls << [ci.item.title, ci.involved_authorities_by_role('editor'), html, false, ci.genre, i, ci]
        i += 1
      end
    else
      @collection.collection_items.each do |ci|
        next if ci.item.present? && ci.item_type == 'Manifestation' && ci.item.status != 'published' # deleted or unpublished manifestations

        html = ci.to_html
        # next unless html.present?
        @htmls << [ci.title, ci.involved_authorities, html.present? ? footnotes_noncer(ci.to_html, i) : '', false, ci.genre,
                   i, ci]
        i += 1
      end
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

  protected

  def downloadable_html(h)
    title, ias, html, is_curated, genre, i, ci = h
    austr = textify_authorities_and_roles(ias)
    out = "<h1>#{title}</h1>\n"
    out += "<h2>#{austr}</h2>" if austr.present?
    out += html
    out.force_encoding('UTF-8')
  end
end
