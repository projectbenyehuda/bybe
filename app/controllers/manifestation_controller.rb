require 'pandoc-ruby'

class ManifestationController < ApplicationController
  include FilteringAndPaginationConcern
  include Tracking
  include BybeUtils
  include KwicConcordanceConcern

  before_action only: %i(list show remove_link edit_metadata add_aboutnesses) do |c|
    c.require_editor('edit_catalog')
  end
  before_action only: %i(edit update) do |c|
    c.require_editor(%w(edit_catalog conversion_verification handle_proofs))
  end
  before_action only: %i(all genre period by_tag) do |c|
    c.refuse_unreasonable_page
  end
  before_action :set_manifestation, only: %i(print read readmode dict dict_print dict_entry_print)

  autocomplete :manifestation, :title, limit: 20, display_value: :title_and_authors, full: true

  # layout false, only: [:print]

  DATE_FIELD = { 'uploaded' => 'manifestations.created_at', 'created' => 'works.normalized_creation_date',
                 'published' => 'expressions.normalized_pub_date' }

  #############################################
  # public actions
  #############################################
  def all
    @page_title = t(:all_works) + ' ' + t(:project_ben_yehuda)
    @pagetype = :works
    @works_list_title = t(:works_list)
    # update the total works count cache if stale, because specifically in "all works" view, the discrepancy is painful
    fresh_count = Manifestation.all_published.count
    if fresh_count != Manifestation.cached_count
      Rails.cache.write('m_count', Manifestation.all_published.count, expires_in: 24.hours)
    end
    browse
  end

  # This method can be called either from other action like `all` with html view and in this case it renders single page
  # or directly with with js format, and then it updates existing html view with a new data after filters refresh or
  # page switch
  def browse
    @pagetype = :works
    @works_list_title = t(:works_list) unless @works_list_title.present? # TODO: adjust by query
    if valid_query?
      es_prep_collection
      @maxdate = Time.zone.today.strftime('%Y-%m')
      @header_partial = 'manifestation/browse_top'

      prep_user_content(:manifestation)
      render :browse
    else
      head :bad_request
    end
  end

  def translations
    @page_title = t(:translations) + ' ' + t(:project_ben_yehuda)
    params['ckb_languages'] = ['xlat']
    browse
  end

  def remove_bookmark
    if base_user
      base_user.bookmarks.where(manifestation_id: params[:id]).first&.destroy
    end
    head :ok
  end

  def set_bookmark
    manifestation_id = params[:id]
    BaseUser.transaction do
      base_user(true).lock!
      b = base_user.bookmarks.where(manifestation_id: manifestation_id).first
      if b.nil?
        base_user.bookmarks.create!(manifestation_id: manifestation_id, bookmark_p: params[:bookmark_path])
      else
        b.update!(bookmark_p: params[:bookmark_path])
      end
      respond_to do |format|
        format.js do
          render partial: 'set_bookmark'
        end
      end
    end
  end

  def by_tag
    @page_title = t(:works_by_tag) + ' ' + t(:project_ben_yehuda)
    @pagetype = :works
    @tag_ids = params[:id]
    tag = Tag.find_by(id: params[:id])
    if tag.present?
      @works_list_title = t(:works_by_tag) + ': ' + tag.name
      browse
    else
      flash[:error] = t(:no_such_item)
      redirect_to '/'
    end
  end

  # Endpoint used to select authority in search filters (can be used by not authenticated visitors)
  # It differs from admin#autocomplete_authority_name_and_aliases by:
  #   - does not require editor access rights
  #   - only shows published authors
  def autocomplete_authority_name
    items = ElasticsearchAutocomplete.call(
      params[:term],
      AuthoritiesAutocompleteIndex,
      %i(name other_designation),
      filter: { term: { published: true } }
    )

    render json: json_for_autocomplete(items, :name)
  end

  def autocomplete_works_by_author
    term = params[:term]
    author = params[:author]
    items = if term && author && term.present? && author.present?
              Authority.find(author.to_i).all_works_by_title(term)
            else
              {}
            end

    render json: json_for_autocomplete(items, :title_and_authors, {}), root: false
  end

  def periods # /periods dashboard
    @tabclass = set_tab('periods')
    @page_title = t(:periods) + ' - ' + t(:project_ben_yehuda)
    @pagetype = :periods
  end

  # This code was used for 'secondary portal', but not used anymore. We may need to reimplement it at some point
  # def works # /works dashboard
  #   @tabclass = set_tab('works')
  #   @page_title = t(:works)+' - '+t(:project_ben_yehuda)
  #   @pagetype = :works
  #   @work_stats = {total: Manifestation.cached_count, pd: Manifestation.cached_pd_count, translated: Manifestation.cached_translated_count}
  #   @work_stats[:permission] = @work_stats[:total] - @work_stats[:pd]
  #   @work_counts_by_genre = Manifestation.cached_work_counts_by_genre
  #   @pop_by_genre = Manifestation.cached_popular_works_by_genre # get popular works by genre + most popular translated
  #   @rand_by_genre = {}
  #   @surprise_by_genre = {}
  #   get_genres.each do |g|
  #     @rand_by_genre[g] = Manifestation.randomize_in_genre_except(@pop_by_genre[g][:orig], g) # get random works by genre
  #     @surprise_by_genre[g] = @rand_by_genre[g].pop # make one of the random works the surprise work
  #   end
  #   @works_abc = Manifestation.first_25 # get cached first 25 manifestations
  #   @new_works_by_genre = Manifestation.cached_last_month_works
  #   @featured_content = featured_content
  #   (@fc_snippet, @fc_rest) = @featured_content.nil? ? ['',''] : snippet(@featured_content.body, 500) # prepare snippet for collapsible
  #   @popular_tags = cached_popular_tags
  # end

  def whatsnew
    @tabclass = set_tab('works')
    @page_title = t(:whatsnew)
    @whatsnew = []
    @anonymous = true
    if params['months'].nil? or params['months'].empty?
      @whatsnew = whatsnew_anonymous
    else
      @whatsnew = whatsnew_since(params[:months].to_i.months.ago)
      @anonymous = false
    end
    @new_authors = Authority.new_since(1.month.ago)
  end

  def like
    unless current_user.nil?
      @m = Manifestation.find(params[:id])
      @m.likers << current_user unless @m.likers.include?(current_user)
    end
    head :ok
  end

  def unlike
    unless current_user.nil?
      @m = Manifestation.find(params[:id])
      @m.likers.delete(current_user) # safely fails if already deleted
    end
    head :ok
  end

  def dict
    if @m.expression.work.genre == 'lexicon'
      @page = params[:page] || 1
      @page = 1 if ['0', ''].include?(@page) # slider sets page to zero or '', awkwardly
      @dict_list_mode = params[:dict_list_mode] || 'list'
      @emit_filters = true if params[:load_filters] == 'true' || params[:emit_filters] == 'true'
      @e = @m.expression
      @header_partial = 'manifestation/dict_top'
      @pagetype = :manifestation
      @page_title = "#{@m.title_and_authors} - #{t(:default_page_title)}"
      @entity = @m
      @print_url = dict_print_path(@m)
      @all_headwords = DictionaryEntry.where(manifestation_id: @m.id)
      unless params[:page].nil? || params[:page].empty?
        params[:to_letter] = nil # if page was specified, forget the to_letter directive
      end
      oldpage = @page
      nonnil_headwords = DictionaryEntry.select(:sequential_number, :sort_defhead).where("manifestation_id = #{@m.id} and defhead is not null").order(sequential_number: :asc) # use paging to calculate first/last in sequence, to allow pleasing lists of 100 items each, no matter how many skipped headwords there are
      @total_headwords = nonnil_headwords.length
      @headwords_page = nonnil_headwords.page(@page)
      @total_pages = @headwords_page.total_pages
      unless params[:to_letter].nil? || params[:to_letter].empty? # for A-Z navigation, we need to adjust the page
        adjust_page_by_letter(nonnil_headwords, params[:to_letter], :sort_defhead, nil, false)
        @headwords_page = nonnil_headwords.page(@page) if oldpage != @page # re-get page X of manifestations if adjustment was made
      end

      @total = @total_headwords # needed?
      @filters = []
      if @headwords_page.count == 0
        first_seqno = 9
        last_seqno = 1 # safely generate zero results in following query
      else
        first_seqno = @headwords_page.first.sequential_number
        last_seqno = @headwords_page.last.sequential_number
      end
      @headwords = DictionaryEntry.where("manifestation_id = #{@m.id} and sequential_number >= #{first_seqno} and sequential_number <= #{last_seqno}").order(sequential_number: :asc)
      @ab = prep_ab(@all_headwords, @headwords_page, :sort_defhead)
    else
      redirect_to action: 'read', id: @m.id
    end
  end

  def dict_entry
    @entry = DictionaryEntry.find(params[:entry])
    @m = Manifestation.find(params[:id])
    if @entry.nil? || @m.nil? || @entry.manifestation_id != @m.id
      head :not_found
      return
    end

    # Check if manifestation is published or user is an editor
    unless @m.published? || current_user&.editor?
      flash.notice = t(:work_not_available)
      redirect_to '/'
    else
      @header_partial = 'manifestation/dict_entry_top'
      @pagetype = :manifestation
      @page_title = "#{@entry.defhead} – #{@m.title_and_authors} – #{t(:default_page_title)}"
      @entity = @m
      @e = @m.expression
      @print_url = dict_entry_print_path(@m, @entry)
      @prev_entries = @entry.get_prev_defs(5)
      @next_entries = @entry.get_next_defs(5)
      @prev_entry = @prev_entries[0] # may be nil if at beginning of dictionary
      @next_entry = @next_entries[0] # may be nil if at [temporary] end of dictionary
      @skipped_to_prev = @prev_entry.nil? ? 0 : @entry.sequential_number - @prev_entry.sequential_number - 1
      @skipped_to_next = @next_entry.nil? ? 0 : @next_entry.sequential_number - @entry.sequential_number - 1
      @incoming_links = @entry.incoming_links.includes(:incoming_links)
      @outgoing_links = @entry.outgoing_links.includes(:outgoing_links)
    end
  end

  def read
    if @m.expression.work.genre == 'lexicon' && DictionaryEntry.exists?(manifestation: @m)
      redirect_to action: 'dict', id: @m.id
    else
      prep_for_read
      @proof = Proof.new
      @new_recommendation = Recommendation.new
      @tagging = Tagging.new
      @tagging.taggable = @m
      @taggings = @m.taggings

      recommendations = @m.recommendations.preload(:user)
      @my_pending_recs = recommendations.select { |r| r.pending? && r.user == current_user }
      @app_recs = recommendations.select(&:approved?)
      @total_recs = @my_pending_recs.size + @app_recs.size

      @links = @m.external_links.group_by { |l| l.linktype }

      @header_partial = 'manifestation/work_top'
      @works_about = @w.works_about
      @scrollspy_target = 'chapternav'
      prep_user_content(:manifestation)
    end
  end

  def readmode
    @readmode = true
    prep_for_read
  end

  def print
    @print = true
    prep_for_print

    @html = MakeHeadingIdsUnique.call(@m.to_html)
    @footer_url = manifestation_url(@m)
  end

  def dict_print
    @print = true
    @e = @m.expression

    if @m.expression.work.genre == 'lexicon'
      # Get all dictionary entries for printing (no pagination)
      @headwords = DictionaryEntry.where(manifestation_id: @m.id).where.not(defhead: nil).order(sequential_number: :asc)
      @footer_url = dict_browse_url(@m)
    else
      redirect_to action: 'print', id: @m.id
    end
  end

  def dict_entry_print
    @print = true
    @entry = DictionaryEntry.find(params[:entry])

    if @entry.manifestation_id != @m.id
      head :not_found
      return
    end

    @e = @m.expression
    @footer_url = dict_entry_url(@m, @entry)
  end

  def download
    format = params[:format]
    unless Downloadable.doctypes.include?(format)
      flash[:error] = t(:unrecognized_format)
      redirect_to manifestation_path(params[:id])
      return
    end

    # NOTE: Asaf disabled this transaction because it caused a failure to attach the downloadable
    #  in dev and testing environments. There is now a check for attachment inside the FreshDownloadable
    #  logic so the transaction is less needed. If you re-enable it, please test thoroughly.
    # Wrapping download code into transaction to make it atomic
    # Without this we had situation when Downloadable object was created but attachmnt creation failed
    # Downloadable.transaction do
    m = Manifestation.find(params[:id])
    dl = GetFreshManifestationDownloadable.call(m, format)
    track_download(m, format)
    redirect_to rails_blob_url(dl.stored_file, disposition: :attachment)
    # end
  end

  def render_html
    @m = Manifestation.find(params[:id])
    @html = MultiMarkdown.new(@m.markdown).to_html.force_encoding('UTF-8').gsub(%r{<figcaption>.*?</figcaption>}, '') # remove MMD's automatic figcaptions
  end

  def period
    @pagetype = :works
    @works_list_title = t(:works_by_period) + ': ' + t(params[:period])
    @periods = [params[:period]]
    browse
  end

  def genre
    @pagetype = :works
    @works_list_title = t(:works_by_genre) + ': ' + helpers.textify_genre(params[:genre])
    if params[:genre].present?
      @genres = [params[:genre]]
      browse
    else
      flash[:error] = t(:no_such_item)
      redirect_to '/'
    end
  end

  # this one is called via AJAX
  def get_random
    work = if params[:genre].present?
             randomize_works_by_genre(params[:genre], 1)[0]
           else
             randomize_works(1)[0]
           end
    render partial: 'shared/surprise_work',
           locals: { passed_mode: params[:mode], manifestation: work, id_frag: params[:id_frag], passed_genre: params[:genre],
                     side: params[:side] }
  end

  def surprise_work
    work = Manifestation.all_published.order(Arel.sql('RAND()')).limit(1)[0]
    render partial: 'surprise_work', locals: { work: work }
  end

  def workshow # temporary action to map to the first manifestation of the work; # TODO: in the future, show something intelligent about multiple expressions per work
    work = Work.find(params[:id])
    unless work.nil?
      m = work.expressions[0].manifestations[0]
      redirect_to action: :read, id: m.id
    else
      flash[:error] = t(:no_such_item)
      redirect_to '/'
    end
  end

  def autocomplete_dict_entry
    term = params[:term]
    # we search *aliases*, to find headwords even without diacritics, or with spelling variants
    items = if term&.present?
              DictionaryAlias.joins(:dictionary_entry).where(dictionary_entry: { manifestation_id: params[:manifestation_id] }).where(
                'alias like ?', "#{term}%"
              ).limit(15)
            else
              {}
            end
    results = items.map do |item|
      val = item.dictionary_entry.defhead
      { id: item.dictionary_entry_id, label: val, value: val }
    end
    render json: results, root: false
  end
  #############################################
  # editor actions

  def remove_image
    @m = Manifestation.find(params[:id])
    did_something = false
    if @m.images.attached?
      rec = @m.images.where(id: params[:image_id])
      unless rec.empty?
        rec[0].purge
        did_something = true
      end
    end
    if did_something
      @img_id = params[:image_id]
      respond_to do |format|
        format.js
      end
    else
      head :ok
    end
  end

  def remove_link
    @m = Manifestation.find(params[:id])
    l = @m.external_links.where(id: params[:link_id])
    unless l.empty?
      l[0].destroy
      flash[:notice] = t(:deleted_successfully)
    else
      flash[:error] = t(:no_such_item)
    end
    redirect_to action: :show, id: params[:id]
  end

  def list
    # calculations
    @page_title = t(:catalog_title)
    @total = Manifestation.count
    # form input
    session[:mft_q_params] = if params[:commit].present?
                               params.permit(%i(title author page)) # make prev. params accessible to view
                             else
                               { title: '', author: '' }
                             end
    @urlbase = url_for(action: :show, id: 1)[0..-2]
    # DB
    if params[:title].blank? && params[:author].blank?
      @manifestations = Manifestation.includes(expression: :work).page(params[:page]).order('updated_at DESC')
    elsif params[:author].blank?
      @manifestations = Manifestation.includes(expression: :work).where('title like ?',
                                                                        '%' + params[:title] + '%').page(params[:page]).order('sort_title ASC')
    elsif params[:title].blank?
      @manifestations = Manifestation.includes(expression: :work).where('cached_people like ?',
                                                                        "%#{params[:author]}%").page(params[:page]).order('sort_title asc')
    else # both author and title
      @manifestations = Manifestation.includes(expression: :work).where(
        'manifestations.title like ? and manifestations.cached_people like ?', '%' + params[:title] + '%', '%' + params[:author] + '%'
      ).page(params[:page]).order('sort_title asc')
    end
  end

  def show
    @m = Manifestation.find(params[:id])
    @page_title = t(:show) + ': ' + @m.title_and_authors
    @e = @m.expression
    @w = @e.work
    @html = MultiMarkdown.new(@m.markdown).to_html.force_encoding('UTF-8').gsub(%r{<figcaption>.*?</figcaption>}, '') # remove MMD's automatic figcaptions
    @html = highlight_suspicious_markdown(@html) # highlight suspicious markdown in backend
    h = @m.legacy_htmlfile
    return if h.nil? or h.url.nil? or h.url.empty?

    @legacy_url = 'https://old.benyehuda.org' + h.url
  end

  def edit
    @m = Manifestation.find(params[:id])
    @page_title = t(:edit_markdown) + ': ' + @m.title_and_authors
    @html = MultiMarkdown.new(@m.markdown).to_html.force_encoding('UTF-8').gsub(%r{<figcaption>.*?</figcaption>}, '') # remove MMD's automatic figcaptions
    @html = highlight_suspicious_markdown(@html) # highlight suspicious markdown in backend
    @markdown = @m.markdown
    h = @m.legacy_htmlfile
    return if h.nil? or h.url.nil? or h.url.empty?

    @legacy_url = 'https://old.benyehuda.org' + h.url
  end

  def edit_metadata
    @m = Manifestation.find(params[:id])
    @page_title = t(:edit_metadata) + ': ' + @m.title_and_authors
    @e = @m.expression
    @w = @e.work
  end

  def chomp_period
    @m = Manifestation.find(params[:id])
    @e = @m.expression
    @w = @e.work
    [@m, @e, @w].each do |rec|
      if rec.title[-1] == '.'
        rec.title = rec.title[0..-2]
        rec.save!
      end
    end
    head :ok
  end

  def add_aboutnesses
    @m = Manifestation.find(params[:id])
    @e = @m.expression
    @w = @e.work
    @page_title = t(:add_aboutnesses) + ': ' + @m.title_and_authors
    @aboutness = Aboutness.new
  end

  def add_images
    @m = Manifestation.find(params[:id])
    prev_count = @m.images.count
    @m.images.attach(params.permit(images: [])[:images])
    new_count = @m.images.count
    flash[:notice] = I18n.t(:uploaded_images, images_added: new_count - prev_count, total: new_count)
    redirect_to action: :show, id: @m.id
  end

  def update
    @m = Manifestation.find(params[:id])
    # update attributes
    if params[:commit] == t(:save)
      Chewy.strategy(:atomic) do
        if params[:markdown].nil? # metadata edit
          @e = @m.expression
          @w = @e.work
          @w.title = params[:wtitle]
          @w.genre = params[:genre]
          @w.orig_lang = params[:wlang]
          @w.origlang_title = params[:origlang_title]
          @w.date = params[:wdate]
          @w.comment = params[:wcomment]
          @w.primary = params[:primary] == 'true'
          @e.language = params[:elang]
          @e.title = params[:etitle]
          @e.date = params[:edate]
          @e.comment = params[:ecomment]
          @e.intellectual_property = params[:intellectual_property]
          @e.source_edition = params[:source_edition]
          @e.period = params[:period]
          @m.title = params[:mtitle]
          @m.sort_title = params[:sort_title]
          @m.alternate_titles = params[:alternate_titles]
          @m.responsibility_statement = params[:mresponsibility]
          @m.comment = params[:mcomment]
          @m.status = params[:mstatus].to_i
          @m.sefaria_linker = params[:sefaria_linker]
          if params[:add_url].present?
            @m.external_links.create!(url: params[:add_url], linktype: params[:link_type].to_i,
                                      description: params[:link_description], status: :approved)
          end
          @w.save!
          @e.save!
        else # markdown edit and save
          unless params[:newtitle].nil? or params[:newtitle].empty?
            @e = @m.expression
            @w = @e.work
            @m.title = params[:newtitle]
            @e.title = params[:newtitle]
            @w.title = params[:newtitle] if @w.orig_lang == @e.language # update work title if work in Hebrew
            @e.save!
            @w.save!
          end
          @m.markdown = params[:markdown]
          @m.conversion_verified = params[:conversion_verified]
        end
        @m.recalc_cached_people
        @m.recalc_heading_lines
        @m.save!
        if current_user.has_bit?('edit_catalog')
          redirect_to action: :show, id: @m.id
        else
          redirect_to controller: :admin, action: :index
        end
        flash[:notice] = I18n.t(:updated_successfully)
      end
    elsif params[:commit] == t(:preview)
      @m = Manifestation.find(params[:id])
      @page_title = t(:edit_markdown) + ': ' + @m.title_and_authors
      @html = MultiMarkdown.new(params[:markdown]).to_html.force_encoding('UTF-8').gsub(%r{<figcaption>.*?</figcaption>}, '') # remove MMD's automatic figcaptions
      @html = highlight_suspicious_markdown(@html) # highlight suspicious markdown in backend
      @markdown = params[:markdown]
      @newtitle = params[:newtitle]

      h = @m.legacy_htmlfile
      unless h.nil? or h.url.nil?
        @legacy_url = 'https://old.benyehuda.org' + h.url
      end
      render action: :edit
    end
  end

  # Display KWIC concordance browser for a manifestation
  def kwic
    @m = Manifestation.find(params[:id])
    if @m.nil?
      head :not_found
      return
    end

    @page_title = "#{t(:kwic_concordance)} - #{@m.title} - #{t(:default_page_title)}"
    @pagetype = :manifestation
    @entity = @m
    @entity_type = 'Manifestation'

    # Use fresh downloadable mechanism to ensure KWIC downloadable exists
    dl = ensure_kwic_downloadable_exists(@m)

    # Parse concordance data from the stored downloadable
    if dl&.stored_file&.attached?
      kwic_text = dl.stored_file.download.force_encoding('UTF-8')
      @concordance_data = ParseKwicConcordance.call(kwic_text)

      # Enrich instances with manifestation ID for context fetching
      @concordance_data.each do |entry|
        entry[:instances].each do |instance|
          instance[:manifestation_id] = @m.id
        end
      end
    else
      # Fallback: generate if downloadable is missing (shouldn't happen after ensure_kwic_downloadable_exists)
      labelled_texts = [{
        label: @m.title,
        buffer: @m.to_plaintext,
        item_id: @m.id,
        item_type: 'Manifestation'
      }]
      @concordance_data = kwic_concordance(labelled_texts)
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
  end

  # Get extended context for a paragraph (AJAX endpoint)
  def kwic_context
    @m = Manifestation.find(params[:id])
    paragraph_num = params[:paragraph].to_i

    context = get_extended_context(@m, paragraph_num)

    render json: {
      prev: context[:prev],
      current: context[:current],
      next: context[:next]
    }
  end

  # Download filtered or full KWIC concordance
  def kwic_download
    @m = Manifestation.find(params[:id])
    if @m.nil?
      head :not_found
      return
    end

    # Generate concordance data
    labelled_texts = [{
      label: @m.title,
      buffer: @m.to_plaintext
    }]
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

    filename = "#{@m.title.gsub(/[^0-9א-תA-Za-z.\-]/, '_')}_kwic.txt"

    send_data kwic_text,
              filename: filename,
              type: 'text/plain; charset=utf-8',
              disposition: 'attachment'
  end

  protected

  def valid_query?
    return true unless params[:to_letter].present? && (params[:to_letter].any_hebrew? == false)
  end

  def bfunc(coll, page, l, field, direction) # binary-search function for ab_pagination
    recs = coll.order(field).page(page)
    rec = recs.first
    return true if rec.nil?

    c = nil
    i = 0
    reccount = recs.count
    while c.nil? && i < reccount
      c = rec[field][0] unless rec[field].nil? # unready dictionary definitions will have their sort_defhead (and defhead) nil, so move on
      i += 1
      rec = recs[i]
    end
    c = '' if c.nil?
    if [:desc, 'desc'].include?(direction)
      return true if c == l || c < l # already too high a page

      return false
    else
      return true if c == l || c > l # already too high a page

      return false
    end
  end

  def adjust_page_by_letter(coll, l, field, direction, is_es)
    # binary search to find page where letter begins
    ret = (1..@total_pages).bsearch do |page|
      if is_es
        es_bfunc(coll, page, l, field, direction)
      else
        bfunc(coll, page, l, field, direction)
      end
    end
    unless ret.nil?
      ret -= 1 unless ret == 1
      @page = ret
    else # bsearch returns nil if last page's bfunc returns false
      @page = @total_pages
    end
  end

  def build_es_filter_from_filters
    ret = {}
    @filters = []
    # periods
    @periods = params['ckb_periods'] unless @periods.present?
    if @periods.present?
      ret['periods'] = @periods
      @filters += @periods.map { |x| [I18n.t(x), "period_#{x}", :checkbox] }
    end

    # genres
    @genres = params['ckb_genres'] unless @genres.present?
    if @genres.present?
      ret['genres'] = @genres
      @filters += @genres.map { |x| [helpers.textify_genre(x), "genre_#{x}", :checkbox] }
    end

    # tags by tag_id
    # Use @tag_ids if already set (from by_tag action), otherwise use params
    tag_ids_source = @tag_ids.present? ? @tag_ids.to_s : params['tag_ids']
    tag_ids_array = tag_ids_source.split(',').map(&:to_i) if tag_ids_source.present?
    if tag_ids_array.present?
      tag_data = Tag.where(id: tag_ids_array).pluck(:id, :name)
      ret['tags'] = tag_data.map(&:last)
      @filters += tag_data.map { |x| [x.last, "tag_#{x.first}", :checkbox] }
      @tag_ids = tag_ids_array.join(',') # Keep as comma-separated string for the form
    end

    # copyright
    @intellectual_property_types = params['ckb_intellectual_property']
    if @intellectual_property_types.present?
      ret['intellectual_property_types'] = @intellectual_property_types
      @filters += @intellectual_property_types.map do |x|
        [helpers.textify_intellectual_property(x), "intellectual_property_#{x}", :checkbox]
      end
    end

    # authors genders
    @genders = params['ckb_genders']
    if @genders.present?
      ret['author_genders'] = @genders
      @filters += @genders.map { |x| [I18n.t(:author) + ': ' + I18n.t(x), "gender_#{x}", :checkbox] }
    end

    # translator genders
    @tgenders = params['ckb_tgenders']
    if @tgenders.present?
      ret['translator_genders'] = @tgenders
      @filters += @tgenders.map { |x| [I18n.t(:translator) + ': ' + I18n.t(x), "tgender_#{x}", :checkbox] }
    end

    # languages
    @languages = params['ckb_languages']
    if @languages.present?
      if @languages == ['xlat']
        @languages = get_langs.reject { |x| x == 'he' }
      else
        @languages.delete('xlat')
      end
      ret['original_languages'] = @languages
      @filters += @languages.map { |x| ["#{I18n.t(:orig_lang)}: #{helpers.textify_lang(x)}", "lang_#{x}", :checkbox] }
    end

    # collection types (in_volume, in_periodical, uncollected)
    @collection_types = params['ckb_collection_types']
    # Only apply filter if not all three are selected (which would mean "show everything")
    if @collection_types.present? && !(@collection_types.sort == %w(in_periodical in_volume uncollected).sort)
      ret['collection_types'] = @collection_types
      @filters += @collection_types.map do |x|
        [I18n.t("collection_type_#{x}"), "collection_type_#{x}", :checkbox]
      end
    end

    # dates
    @fromdate = params['fromdate'].to_i if params['fromdate'].present?
    @todate = params['todate'].to_i if params['todate'].present?
    @datetype = params['date_type']
    range_expr = {}

    if @fromdate.present?
      range_expr['from'] = @fromdate
      @filters << ["#{I18n.t('d' + @datetype)} #{I18n.t(:fromdate)}: #{@fromdate}", :fromdate, :text]
    end

    if @todate.present?
      range_expr['to'] = @todate
      @filters << ["#{I18n.t('d' + @datetype)} #{I18n.t(:todate)}: #{@todate}", :todate, :text]
    end

    unless range_expr.empty?
      raise "Wrong datetype: #{@datetype}" unless %w(uploaded created published).include?(@datetype)

      datefield = "#{@datetype}_between"
      ret[datefield] = range_expr
    end

    # author ids - multi-select authors
    if params['authors'].present?
      author_ids = params['authors'].split(',').map(&:to_i)
      ret['author_ids'] = author_ids
      @authors = author_ids # .join(',')
      @authors_names = params['authors_names']
      @filters << [I18n.t(:authors_xx, xx: @authors_names), 'authors', :authorlist]
    end

    # in browse UI we can search by author name or by title
    @search_type = params['search_type'] || 'authorname'
    if @search_type == 'authorname'
      @authorstr = params['authorstr']
      @search_input = ''
      if @authorstr.present?
        ret['author'] = @authorstr
        @filters << [I18n.t(:author_x, x: @authorstr), :authors, :text]
      end
    else
      @authorstr = ''
      @search_input = params['search_input']
      if @search_input.present?
        ret['title'] = @search_input
        @filters << [I18n.t(:title_x, x: @search_input), :search_input, :text]
      end
    end

    # fulltext search is a separate filter
    @fulltext_input = params['fulltext_input']
    if @fulltext_input.present?
      ret['fulltext'] = @fulltext_input
      @filters << [I18n.t(:text_contains_x, x: @fulltext_input), :fulltext_input, :text]
    end

    return ret
  end

  def prepare_totals(collection)
    standard_aggregations = {
      periods: { terms: { field: 'period' } },
      genres: { terms: { field: 'genre' } },
      languages: { terms: { field: 'orig_lang', size: get_langs.count + 1 } },
      intellectual_property_types: { terms: { field: 'intellectual_property' } },
      author_genders: { terms: { field: 'author_gender' } },
      translator_genders: { terms: { field: 'translator_gender' } },
      # We may need to increase `size` threshold in future if number of authors exceeds 2000
      author_ids: { terms: { field: 'author_ids', size: 2000 } },
      in_volume: { terms: { field: 'in_volume' } },
      in_periodical: { terms: { field: 'in_periodical' } }
    }

    collection = collection.aggregations(standard_aggregations)

    @gender_facet = buckets_to_totals_hash(collection.aggs['author_genders']['buckets'])
    @tgender_facet = buckets_to_totals_hash(collection.aggs['translator_genders']['buckets'])
    @period_facet = buckets_to_totals_hash(collection.aggs['periods']['buckets'])
    @genre_facet = buckets_to_totals_hash(collection.aggs['genres']['buckets'])
    @intellectual_property_facet = buckets_to_totals_hash(collection.aggs['intellectual_property_types']['buckets'])

    @language_facet = buckets_to_totals_hash(collection.aggs['languages']['buckets'])
    @language_facet[:xlat] = @language_facet.except('he').values.sum

    # Build collection type facet from in_volume and in_periodical aggregations
    in_volume_aggs = buckets_to_totals_hash(collection.aggs['in_volume']['buckets'])
    in_periodical_aggs = buckets_to_totals_hash(collection.aggs['in_periodical']['buckets'])

    @collection_type_facet = {
      'in_volume' => in_volume_aggs[1] || 0,
      'in_periodical' => in_periodical_aggs[1] || 0,
      'uncollected' => if in_volume_aggs[0] && in_periodical_aggs[0]
                         [in_volume_aggs[0], in_periodical_aggs[0]].min
                       else
                         0
                       end
    }

    # Preparing list of authors to show in multiselect modal on works browse page
    if collection.filter.present?
      author_ids = collection.aggs['author_ids']['buckets'].pluck('key')
      @authors_list = Authority.where(id: author_ids)
    else
      @authors_list = Authority.all
    end
    @authors_list = @authors_list.select(:id, :name).sort_by(&:name)
  end

  def get_sort_column(sort_by)
    SearchManifestations::SORTING_PROPERTIES[sort_by][:column]
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

    @collection = SearchManifestations.call(@sort_by, sort_dir_to_use, filter)

    # Adding filtering by first letter
    @to_letter = params['to_letter']
    if @to_letter.present?
      @collection = @collection.filter({ prefix: { sort_title: @to_letter } })
      @filters << [I18n.t(:title_starts_with_x, x: @to_letter), :to_letter, :text]
    end

    @works = paginate(@collection)
  end

  def prep_ab(whole, subset, fieldname)
    ret = []
    abc_present = whole.pluck(fieldname).map { |t| t.blank? ? '' : t[0] }.uniq.sort
    subset[0] # bizarrely, unless we force this query, the pluck below returns *a wrong set* (off by one page or so)
    abc_active = subset.pluck(fieldname).map { |t| t.blank? ? '' : t[0] }.uniq.sort
    LETTERS.each do |l|
      status = ''
      unless abc_present.include?(l)
        status = abc_active.empty? || l >= abc_active.last ? :disabled : :in_range_disabled
      end
      status = :active if abc_active.include?(l)
      ret << [l, status]
    end
    return ret
  end

  def refuse_unreasonable_page
    return true if params[:page].nil? || params[:page].empty?

    p = params[:page].to_i
    return true unless p.nil? || p > 2000

    head(:forbidden)
  end

  def prep_for_print
    @e = @m.expression
    @w = @e.work

    # We track view event for text itself and for all authors and translators
    track_view(@m)
    @m.authors.each { |author| track_view(author) }
    @m.translators.each { |translator| track_view(translator) }

    @author = @w.authors[0] # TODO: handle multiple authors
    if @author.nil?
      @author = Authority.new(name: '?')
    end
    @translators = @m.translators
    @illustrators = @m.involved_authorities_by_role(:illustrator)
    @editors = @m.involved_authorities_by_role(:editor)
    @page_title = "#{@m.title_and_authors} - #{t(:default_page_title)}"
  end

  def prep_for_read
    prep_for_print

    chapters_data = Rails.cache.fetch("#{@m.cache_key_with_version}_with_chapters", expires_in: 24.hours) do
      ManifestationHtmlWithChapters.call(@m)
    end

    @html = chapters_data[:html]
    @chapters = chapters_data[:chapters]

    @tabclass = set_tab('works')
    @entity = @m
    @pagetype = :manifestation
    @liked = (current_user.nil? ? false : @m.likers.include?(current_user))
    if @e.translation? && (@e.work.expressions.count > 1) # one is the one we're looking at...
      @additional_translations = []
      @e.work.expressions.joins(:manifestations).includes(:manifestations).each do |ex|
        @additional_translations << ex unless ex == @e
      end
    end
    @containments = @m.collection_items.preload(collection: :collection_items).to_a
    @volumes = @m.volumes
    if !@volumes.empty? && @containments.any? { |ci| ci.collection.uncollected? }
      # if the text is in a volume, its inclusion in an uncollected collection is stale
      @m.trigger_uncollected_recalculation # async update the uncollected collection this text was still in
      @containments.reject! { |ci| ci.collection.uncollected? }
    end
    @single_text_volume = @containments.size == 1 && !@containments.first.collection.has_multiple_manifestations?
  end

  private

  def set_manifestation
    @m = Manifestation.find(params[:id])

    return if @m.published? || current_user&.editor?

    flash.notice = t(:work_not_available)
    redirect_to '/'
  end
end
