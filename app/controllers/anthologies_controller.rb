class AnthologiesController < ApplicationController
  include Tracking

  before_action :set_anthology, only: %i(show clone print seq download edit update destroy)

  # GET /anthologies
  def index
    @anthologies = Anthology.pub.page(params[:page])
  end

  # GET/POST /anthologies/browse
  def browse
    @page_title = "#{t(:anthologies_list)} – #{t(:project_ben_yehuda)}"
    @pagetype = :anthologies

    # Start with public anthologies only
    @anthologies = Anthology.public_anthology.includes(:user, texts: { manifestation: { expression: { work: { involved_authorities: :authority } } } })

    # Apply filters
    @filters = []

    # Filter by title
    if params[:title_filter].present?
      @title_filter = params[:title_filter]
      @anthologies = @anthologies.where("anthologies.title LIKE ?", "%#{@title_filter}%")
      @filters << [t(:title_filter_label, title: @title_filter), 'title_filter', 'text']
    end

    # Filter by author name
    if params[:author_filter].present?
      @author_filter = params[:author_filter]
      @anthologies = @anthologies.joins(texts: { manifestation: { expression: { work: { involved_authorities: :authority } } } })
                                 .where("authorities.name LIKE ?", "%#{@author_filter}%")
                                 .distinct
      @filters << [t(:author_filter_label, author: @author_filter), 'author_filter', 'text']
    end

    # Filter by manifestation title
    if params[:manifestation_filter].present?
      @manifestation_filter = params[:manifestation_filter]
      @anthologies = @anthologies.joins(texts: :manifestation)
                                 .where("manifestations.title LIKE ?", "%#{@manifestation_filter}%")
                                 .distinct
      @filters << [t(:manifestation_filter_label, title: @manifestation_filter), 'manifestation_filter', 'text']
    end

    # Filter by owner name
    if params[:owner_filter].present?
      @owner_filter = params[:owner_filter]
      @anthologies = @anthologies.joins(:user)
                                 .where("users.name LIKE ?", "%#{@owner_filter}%")
                                 .distinct
      @filters << [t(:owner_filter_label, owner: @owner_filter), 'owner_filter', 'text']
    end

    # Sorting
    @sort = params[:sort_by] || 'alphabetical_asc'
    @anthologies = case @sort
                   when 'alphabetical_asc'
                     @anthologies.order('anthologies.title ASC')
                   when 'alphabetical_desc'
                     @anthologies.order('anthologies.title DESC')
                   when 'created_date_asc'
                     @anthologies.order('anthologies.created_at ASC')
                   when 'created_date_desc'
                     @anthologies.order('anthologies.created_at DESC')
                   else
                     @anthologies.order('anthologies.title ASC')
                   end

    # Pagination
    @page = (params[:page] || 1).to_i
    @per_page = 50

    # Cache the count query for performance (especially with joins)
    cache_key_filters = params.slice(:title_filter, :author_filter, :manifestation_filter, :owner_filter, :sort_by).to_unsafe_h
    @total = Rails.cache.fetch(['anthologies_browse_total', cache_key_filters], expires_in: 5.minutes) do
      @anthologies.distinct.count(:id)
    end

    @total_pages = (@total / @per_page.to_f).ceil
    @anthologies = @anthologies.offset((@page - 1) * @per_page).limit(@per_page)

    respond_to do |format|
      format.html
      format.js
    end
  end

  # GET /anthologies/1
  def show
    @cur_anth_id = @anthology.nil? ? 0 : @anthology.id
    if @anthology.accessible?(current_user)
      session[:current_anthology_id] = @anthology.id
      respond_to do |format|
        format.js
        format.html do
          @header_partial = 'anthology_top'
          @scrollspy_target = 'chapternav'
          prep_for_show
          @print_url = url_for(action: :print, id: @anthology.id)
          track_view(@anthology)
        end
      end
    else
      redirect_to '/', error: t(:no_permission)
    end
  end

  def clone
    if @anthology.accessible?(current_user)
      @na = @anthology.dup
      @na.sequence = ''
      @na.user = current_user # whoever owned it before (could clone a public anth owned by someone else)
      @na.access = :priv # default to private after cloning
      @na.title = t(:copy_of) + @na.title
      @na.save!
      # now clone anth items
      @anthology.ordered_texts.each do |item|
        nitem = item.dup
        nitem.anthology = @na
        nitem.save!
        @na.append_to_sequence(nitem.id)
      end
      @anthology = @na # make the cloned anthology the current one
      @cur_anth_id = @anthology.nil? ? 0 : @anthology.id
      @na.reload
      @na.cached_page_count = @na.page_count(true) # force refresh
      @na.save!
      respond_to do |format|
        format.js
        format.html { redirect_to @anthology, notice: t(:anthology_cloned) }
      end
    else
      redirect_to '/', error: t(:no_permission)
    end
  end

  def download
    if @anthology.accessible?(current_user)
      format = params[:format]
      unless Downloadable.doctypes.include?(format)
        flash[:error] = t(:unrecognized_format)
        redirect_to @anthology # TODO: handle anthology case
        return
      end

      dl = @anthology.fresh_downloadable_for(format)
      if dl.nil?
        prep_for_show
        filename = "#{@anthology.title.gsub(/[^0-9א-תA-Za-z.\-]/, '_')}.#{format}"

        if format == 'kwic'
          # Generate KWIC concordance for anthology
          labelled_texts = []
          @anthology.texts.is_text.each do |at|
            next if at.manifestation.nil?

            labelled_texts << {
              label: at.manifestation.title,
              buffer: at.manifestation.to_plaintext
            }
          end
          kwic_text = GenerateKwicConcordance.call(labelled_texts)
          austr = begin
            @anthology.user.name
          rescue StandardError
            ''
          end
          dl = MakeFreshDownloadable.call(params[:format], filename, '', @anthology, austr, kwic_text: kwic_text)
        else
          html = "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\"><html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"he\" lang=\"he\" dir=\"rtl\"><head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" /></head><body dir='rtl'><div dir=\"rtl\" align=\"right\">#{@anthology.title}" + @htmls.map { |h|
                                                                                                                                                                                                                                                                                                                                                                                                                  "<h1>#{h[0]}</h1>\n#{h[1]}"
                                                                                                                                                                                                                                                                                                                                                                                                                }.join("\n").force_encoding('UTF-8') + "\n\n<hr />" + I18n.t(:download_footer_html,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                             url: url_for(action: :show,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          id: @anthology.id)) + '</div></body></html>'
          austr = begin
            @anthology.user.name
          rescue StandardError
            ''
          end
          dl = MakeFreshDownloadable.call(params[:format], filename, html, @anthology, austr)
        end
      end
      track_download(@anthology, format)
      redirect_to rails_blob_url(dl.stored_file, disposition: :attachment)
    else
      redirect_to '/', error: t(:no_permission)
    end
  end

  def print
    @print = true
    @footer_url = url_for(action: :show, id: @anthology.id)
    if @anthology.accessible?(current_user)
      prep_for_show
      track_view(@anthology)
    else
      redirect_to '/', error: t(:no_permission)
    end
  end

  def seq
    p = params.permit(:id, :old_pos, :new_pos, :anth_text_id)
    @anthology.update_sequence(p[:anth_text_id].to_i, p[:old_pos].to_i, p[:new_pos].to_i)
  end

  # GET /anthologies/new
  def new
    @anthology = Anthology.new
  end

  # GET /anthologies/1/edit
  def edit
  end

  # POST /anthologies
  def create
    @anthology = Anthology.new(anthology_params)
    begin
      if @anthology.save
        @cur_anth_id = @anthology.nil? ? 0 : @anthology.id
        @anthologies = current_user.anthologies
        @new_anth_name = generate_new_anth_name_from_set(@anthologies)

        respond_to do |format|
          format.js
          format.html { redirect_to @anthology, notice: 'Anthology was successfully created.' }
        end
      else
        respond_with_error
      end
    rescue ActiveRecord::RecordInvalid
      respond_with_error
    end
  end

  def respond_with_error
    # show anthErrorDlg if necessary
    @cur_anth_id = @anthology.nil? || @anthology.id.nil? ? 0 : @anthology.id
    @error = true
    response.status = 200
    respond_to do |format|
      format.js
      format.html { redirect_to @anthology, notice: @anthology.errors[:base][0] }
    end
  end

  # PATCH/PUT /anthologies/1
  def update
    @anthology.update!(anthology_params)
    @cur_anth_id = @anthology.nil? ? 0 : @anthology.id
    @error = false
    respond_to do |format|
      format.js
      format.html { redirect_to @anthology, notice: 'Anthology was successfully updated.' }
    end
  rescue ActiveRecord::RecordInvalid
    # show anthErrorDlg if necessary
    respond_with_error
  end

  # DELETE /anthologies/1
  def destroy
    @anthology.destroy
    @anthologies = current_user.anthologies
    unless @anthologies.empty?
      @anthology = @anthologies.first
      session[:current_anthology_id] = @anthology.id
    else
      @anthology = nil
      session[:current_anthology_id] = nil
    end
    @cur_anth_id = @anthology.nil? ? 0 : @anthology.id
    respond_to do |format|
      format.js
      format.html { redirect_to anthologies_url, notice: 'Anthology was successfully destroyed.' }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_anthology
    @anthology = Anthology.find(params[:id])
  end

  def anthology_params
    params.require(:anthology).permit(:title, :access, :sequence, :user_id)
  end

  def prep_for_show
    @htmls = []
    i = 1
    @anthology.ordered_texts.each do |text|
      @htmls << [text.title, footnotes_noncer(text.render_html, i), text.manifestation_id.nil? ? true : false,
                 text.manifestation_id.nil? ? nil : text.manifestation.expression.work.genre, i]
      i += 1
    end
  end
end
