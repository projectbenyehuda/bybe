require 'diffy'
include BybeUtils
include ApplicationHelper

class AuthorsController < ApplicationController
  include FilteringAndPaginationConcern
  include Tracking
  include KwicConcordanceConcern

  before_action only: %i(new publish create show edit list add_link delete_link
                         delete_photo edit_toc update to_manual_toc add_link manage_toc volumes) do |c|
    c.require_editor('edit_people')
  end

  before_action :set_author,
                only: %i(show edit update destroy toc edit_toc print all_links delete_photo
                         whatsnew_popup latest_popup publish to_manual_toc volumes
                         kwic kwic_download kwic_context)
  layout 'backend', only: %i(manage_toc)

  def publish
    if params[:commit].present?
      # POST request
      if @author.unpublished? && @author.all_works_including_unpublished.count > 0
        @author.publish!
        Rails.cache.delete('newest_authors') # force cache refresh
        Rails.cache.delete('homepage_authors')
        Rails.cache.delete("au_#{@author.id}_work_count")
        flash[:success] = t(:published)
      else
        @author.awaiting_first!
        flash[:success] = t(:awaiting_first)
      end
      redirect_to action: :list
    else
      # GET request
      @manifestations = @author.all_works_including_unpublished
    end
  end

  def volumes
    render json: { volumes: @author.volumes.sort_by(&:title),
                   publications: @author.publications.no_volume.sort_by(&:title) }
  end

  def get_random_author
    genre = params[:genre]
    render partial: 'shared/surprise_author',
           locals: {
             author: RandomAuthor.call(genre),
             initial: false,
             id_frag: params[:id_frag],
             passed_genre: genre,
             passed_mode: params[:mode],
             side: params[:side]
           }
  end

  def delete_photo
    if @author.profile_image.file?
      @author.profile_image.destroy
      @author.save!
      flash[:notice] = t(:deleted_successfully)
    end
    show
    render action: :show
  end

  def whatsnew_popup
    pubs = @author.works_since(1.month.ago, 1000)
    @pubs = TextifyNewPubs.call(pubs)
    render partial: 'whatsnew_popup'
  end

  def latest_popup
    @pubs = Rails.cache.fetch("au_#{@author.id}_latest_popup", expires_in: 12.hours) do
      pubs = @author.latest_stuff.preload(expression: :work)
      TextifyNewPubs.call(pubs)
    end

    render partial: 'whatsnew_popup'
  end

  def es_datefield_name_from_datetype(dt)
    case dt
    when 'uploaded'
      return 'pby_publication_date'
    when 'birth'
      return 'person.birth_year'
    when 'death'
      return 'person.death_year'
    end
  end

  def build_es_filter_from_filters
    ret = []
    @filters = []
    # periods
    @periods = params['ckb_periods'] if params['ckb_periods'].present?
    if @periods.present?
      ret << { terms: { 'person.period' => @periods } }
      @filters += @periods.map { |x| [I18n.t(x), "period_#{x}", :checkbox] }
    end
    # genders
    @genders = params['ckb_genders'] if params['ckb_genders'].present?
    if @genders.present?
      ret << { terms: { 'person.gender' => @genders } }
      @filters += @genders.map { |x| ["#{I18n.t(:author)}: #{I18n.t(x)}", "gender_#{x}", :checkbox] }
    end
    # genres
    @genres = params['ckb_genres'] if params['ckb_genres'].present?
    if @genres.present?
      ret << { terms: { genre: @genres } }
      @filters += @genres.map { |x| [helpers.textify_genre(x), "genre_#{x}", :checkbox] }
    end
    # copyright
    @intellectual_property_types = params['ckb_intellectual_property']
    if @intellectual_property_types.present?
      ret << { terms: { intellectual_property: @intellectual_property_types } }
      @filters += @intellectual_property_types.map do |ip|
        [helpers.textify_intellectual_property(ip), "intellectual_property_#{ip}", :checkbox]
      end
    end
    # languages
    if params['ckb_languages'].present?
      @languages = params['ckb_languages'].reject { |x| x == 'xlat' }
      if @languages.present?
        ret << { terms: { language: @languages } }
        @filters += @languages.map { |x| ["#{I18n.t(:orig_lang)}: #{helpers.textify_lang(x)}", "lang_#{x}", :checkbox] }
      end
    end
    # tags by tag_id
    # Use @tag_ids if already set (from by_tag action), otherwise use params
    tag_ids_source = @tag_ids.present? ? @tag_ids.to_s : params['tag_ids']
    tag_ids_array = tag_ids_source.split(',').map(&:to_i) if tag_ids_source.present?
    if tag_ids_array.present?
      tag_data = Tag.where(id: tag_ids_array).pluck(:id, :name)
      ret << { terms: { tags: tag_data.map(&:last) } }
      @filters += tag_data.map { |x| [x.last, "tag_#{x.first}", :checkbox] }
      @tag_ids = tag_ids_array.join(',') # Keep as comma-separated string for the form
    end

    # dates
    @fromdate = params['fromdate'] if params['fromdate'].present?
    @todate = params['todate'] if params['todate'].present?
    @datetype = params['date_type']
    range_expr = {}
    if @fromdate.present?
      range_expr['gte'] = @fromdate
      @filters << ["#{I18n.t('d' + @datetype)} #{I18n.t(:fromdate)}: #{@fromdate}", :fromdate, :text]
    end
    if @todate.present?
      range_expr['lte'] = @todate
      @filters << ["#{I18n.t('d' + @datetype)} #{I18n.t(:todate)}: #{@todate}", :todate, :text]
    end
    datefield = es_datefield_name_from_datetype(@datetype)
    ret << { range: { "#{datefield}" => range_expr } } unless range_expr.empty?

    # Adding filtering by first letter
    @to_letter = params['to_letter']
    if @to_letter.present?
      ret << { prefix: { sort_name: @to_letter } }
      @filters << [I18n.t(:name_starts_with_x, x: @to_letter), :to_letter, :text]
    end

    return ret
  end

  def build_es_query_from_filters
    ret = {}
    if params['search_input'].present?
      ret['match'] = { name: params['search_input'] }
      @filters << [I18n.t(:author_x, x: params['search_input']), :search_input, :text]
      @search_input = params['search_input']
    end
    return ret
  end

  def prepare_totals(collection)
    standard_aggregations = {
      periods: { terms: { field: 'person.period' } },
      genres: { terms: { field: 'genre' } },
      languages: { terms: { field: 'language', size: get_langs.count + 1 } },
      intellectual_property_types: { terms: { field: 'intellectual_property' } },
      genders: { terms: { field: 'person.gender' } }
    }

    collection = collection.aggregations(standard_aggregations)

    @gender_facet = buckets_to_totals_hash(collection.aggs['genders']['buckets'])
    @period_facet = buckets_to_totals_hash(collection.aggs['periods']['buckets'])
    @genre_facet = buckets_to_totals_hash(collection.aggs['genres']['buckets'])
    @language_facet = buckets_to_totals_hash(collection.aggs['languages']['buckets'])
    @language_facet[:xlat] = @language_facet.except('he').values.sum
    @intellectual_property_facet = buckets_to_totals_hash(collection.aggs['intellectual_property_types']['buckets'])
  end

  SORTING_PROPERTIES = {
    'alphabetical' => { default_dir: 'asc', column: :sort_name },
    'popularity' => { default_dir: 'desc', column: :impressions_count },
    'death_date' => { default_dir: 'asc', column: 'person.death_year' },
    'birth_date' => { default_dir: 'asc', column: 'person.birth_year' },
    'upload_date' => { default_dir: 'desc', column: :pby_publication_date }
  }.freeze

  def get_sort_column(sort_by)
    SORTING_PROPERTIES[sort_by][:column]
  end

  def es_prep_collection
    @sort_dir = 'default'
    if params[:sort_by].present?
      @sort = params[:sort_by].dup
      @sort_by = params[:sort_by].sub(/_(a|de)sc$/, '')
      @sort_dir = Regexp.last_match(0)[1..] unless Regexp.last_match(0).nil?
    else
      # use alphabetical sorting by default
      @sort = 'alphabetical_asc'
      @sort_by = 'alphabetical'
      @sort_dir = 'asc'
    end

    # This param means that we're getting previous page
    # so we should revert sort ordering while quering ElasticSearch index
    @reverse = params[:reverse] == 'true'
    sort_dir_to_use = if @reverse
                        @sort_dir == 'asc' ? 'desc' : 'asc'
                      else
                        @sort_dir
                      end
    ord = { SORTING_PROPERTIES[@sort_by][:column] => sort_dir_to_use, id: sort_dir_to_use }

    filter = build_es_filter_from_filters
    es_query = build_es_query_from_filters
    es_query = { match_all: {} } if es_query == {}

    @collection = AuthoritiesIndex.query(es_query)
                                  .filter(filter)
                                  .order(ord)

    @authors = paginate(@collection)
  end

  def browse
    @page_title = "#{t(:authors_list)} – #{t(:project_ben_yehuda)}"
    @pagetype = :authors
    @page = 1 if ['0', ''].include?(@page) # slider sets page to zero, awkwardly
    es_prep_collection
    @total = @collection.count
    @maxdate = Time.zone.today.strftime('%Y-%m')
    @header_partial = 'authors/browse_top'
    @authors_list_title = t(:author_list) unless @authors_list_title.present?
    render :browse
    respond_to do |format|
      format.html
      format.js
    end
  end

  def all
    # This action is used for backward compatibility.
    # The URL /authors/all did exist at one time, and may be linked to from outside our site, and we want not to
    # break it, but to seamlessly redirect it to just /authors.
    redirect_to authors_path
  end

  def by_tag
    @page_title = t(:authors_by_tag) + ' ' + t(:project_ben_yehuda)
    @pagetype = :authors
    tid = params[:id].to_i
    @tag_ids = tid
    tag = Tag.find_by(id: tid)
    if tag.present?
      @authors_list_title = t(:authors_by_tag) + ': ' + tag.name
      browse
    else
      flash[:error] = t(:no_such_item)
      redirect_to '/'
    end
  end

  def to_manual_toc
    if @author.toc.nil?
      @works = @author.original_works_by_genre # deliberately NOT using cache here
      @translations = @author.translations_by_genre
      @genres_present = []
      @works.each_key { |k| @genres_present << k unless @works[k].empty? || @genres_present.include?(k) }
      @translations.each_key { |k| @genres_present << k unless @works[k].empty? || @genres_present.include?(k) }
      toc = ''
      get_genres.each do |genre|
        next if @works[genre].empty? && @translations[genre].empty?

        toc += "## #{textify_genre(genre)}\n"
        unless @works[genre].empty?
          @works[genre].each do |m|
            toc += "&&& פריט: מ#{m.id} &&& כותרת: #{m.title.strip} &&&"
            if m.authors.count > 1
              add_authors = m.authors.reject { |au| au == @author }.map(&:name).join('; ')
              toc += "(#{t(:with)} #{add_authors})"
            end
            if m.expression.translation
              toc += " #{t(:translated_by)} "
              toc += m.expression.translators.map(&:name).join('; ')
            end
            toc += "\n\n"
          end
        end

        next if @translations[genre].empty?

        toc += "### #{t(:translation)}\n"
        @translations[genre].each do |m|
          toc += "&&& פריט: מ#{m.id} &&& כותרת: #{m.title.strip} &&&"
          toc += t(:by)
          toc += m.expression.work.first_author.name
        end
      end
      newtoc = Toc.new(toc: toc, status: :raw, credit_section: '')
      newtoc.save!
      @author.toc = newtoc
      @author.save!
      flash[:notice] = t(:created_toc)
    else
      flash[:error] = t(:already_has_toc)
    end
    redirect_to authors_edit_toc_path(id: @author.id)
  end

  def show
    @published_works = @author.original_works.count
    @published_xlats = @author.translations.count
    @total_orig_works = @author.manifestations(:author).count
    @total_xlats = @author.manifestations(:translator).count

    if @author.nil?
      flash[:error] = t(:no_such_item)
      redirect_to '/'
    else
      # TODO: add other types of content
      @page_title = "#{t(:author_details)}: #{@author.name}"
    end
  end

  def new
    @author = Authority.new(intellectual_property: :unknown, name: params[:name])
    type = params[:type]
    if type == 'person'
      @author.person = Person.new
    elsif type == 'corporate_body'
      @author.corporate_body = CorporateBody.new
    else
      raise "Unknown type: '#{type}'"
    end

    @page_title = t(:new_author)
  end

  def create
    Chewy.strategy(:atomic) do
      @author = Authority.new(authority_params)
      if @author.status.blank?
        @author.status = @author.intellectual_property_public_domain? ? :awaiting_first : :unpublished
      end

      if @author.save
        flash.notice = t(:created_successfully)
        redirect_to action: :show, params: { id: @author.id }
      else
        render action: :new, status: :unprocessable_content
      end
    end
  end

  def destroy
    Chewy.strategy(:atomic) do
      @author.destroy!
      redirect_to action: :list
    end
  end

  def edit
    @page_title = "#{t(:edit)}: #{@author.name}"
  end

  def update
    Chewy.strategy(:atomic) do
      if @author.update(authority_params)
        # if period was updated, update the period of this person's Expressions
        if @author.person.present? && @author.person.period_previously_changed?
          # In our system period states for Hebrew text period. So for original Hebrew works it should match
          # period of author, and if this is a translation from other language to Hebrew, it should match period of
          # translator. See https://github.com/abartov/bybeconv/issues/149#issuecomment-1141062929
          o = @author.original_works.preload(expression: :work).map(&:expression)
                     .select { |e| e.work.orig_lang == 'he' }
          t = @author.translations.preload(:expression).map(&:expression)
                     .select { |e| e.language == 'he' } # we have few translations from Hebrew to other languages
          (o + t).uniq.each { |e| e.update(period: @author.person.period) }
        end
        if @author.status_changed? && @author.status == 'published'
          @author.publish!
          Rails.cache.delete('newest_authors') # force cache refresh
          Rails.cache.delete('homepage_authors')
          Rails.cache.delete("au_#{@author.id}_work_count")
        end
        @author.invalidate_cached_credits!
        flash[:notice] = I18n.t(:updated_successfully)
        redirect_to action: :show, id: @author.id
      else
        render action: 'edit', status: :unprocessable_content
      end
    end
  end

  def list
    @page_title = "#{t(:authors)} - #{t(:project_ben_yehuda)}"

    # TODO: pagination
    @authorities = Authority.left_joins(:toc)
                            .page(params[:page])
                            .order(params[:order].nil? ? ['tocs.status, sort_name'] : params[:order])

    @q = params[:q].strip unless params[:q].nil?
    return if @q.blank?

    @authorities = @authorities.where('name like ? or other_designation like ?', "%#{@q}%", "%#{@q}%")
  end

  def add_link
    @author = Authority.find(params[:id])
    if params[:link_description].empty? || params[:add_url].empty?
      head :bad_request
    else
      @el = ExternalLink.create!(
        linkable: @author,
        description: params[:link_description],
        linktype: params[:link_type].to_i,
        url: params[:add_url],
        status: :approved
      )
    end
  end

  def delete_link
    @el = ExternalLink.find(params[:id])
    if @el.nil?
      flash[:error] = t(:no_such_item)
      redirect_to '/'
    else
      @el.destroy
      head :ok
    end
  end

  def toc
    if @author.published? || (current_user.present? && current_user.editor?)
      # Note that we are accessing an unpublished author, if that's the case
      @unpublished = true unless @author.published?

      @tabclass = set_tab('authors')
      @print_url = url_for(action: :print, id: @author.id)
      @pagetype = :author
      @header_partial = 'authors/author_top'
      @entity = @author
      @page_title = "#{@author.name} - #{t(:author_table_of_contents)} - #{t(:project_ben_yehuda)}"
      track_view(@author)

      @og_image = @author.profile_image.url(:thumb)
      @featured = @author.featured_work
      @external_links = @author.external_links.status_approved
      @any_curated = @featured.present? || !@author.aboutnesses.empty?
      unless @featured.empty?
        (@fc_snippet, @fc_rest) = snippet(@featured[0].body, 500) # prepare snippet for collapsible
      end
      @taggings = @author.taggings.preload(:tag)

      @credits = render_to_string(partial: 'authors/credits', locals: { author: @author })
      if @author.toc.present?
        prep_toc
      else
        unless @author.uncollected_works_collection_id.present?
          RefreshUncollectedWorksCollection.call(@author)
        end
        # generate_toc # legacy generated TOC
        # Pre-calculate TOC tree and counts for efficiency (used in both navbar and TOC body)
        @toc_tree = GenerateTocTree.call(@author)
        @toc_counts = calculate_toc_counts(@toc_tree, @author.id)
      end
      if @author.lexicon_entry.present?
        @lexicon_entry = @author.lexicon_entry
      end
      prep_user_content(:author)
      @scrollspy_target = 'genrenav'
    else
      flash[:error] = I18n.t(:author_not_available)
      redirect_to '/'
    end
  end

  def all_links
    unless @author.nil?
      @external_links = @author.external_links.status_approved
      render partial: 'all_links'
    else
      flash[:error] = I18n.t(:no_toc_yet)
      redirect_to '/'
    end
  end

  def print
    @print = true
    prep_for_print
    @footer_url = url_for(action: :toc, id: @author.id)
  end

  def edit_toc
    if @author.nil?
      flash[:error] = I18n.t('no_such_item')
      redirect_to '/'
    elsif @author.toc.nil?
      flash[:error] = I18n.t('no_toc_yet')
      redirect_to '/'
    else
      @page_title = t(:edit_toc) + ': ' + @author.name
      unless params[:markdown].nil? # handle update payload
        if params[:old_timestamp].to_datetime == @author.toc.updated_at.to_datetime
          t = @author.toc
          t.toc = params[:markdown]
          t.credit_section = params[:credits]
          t.status = Toc.statuses[params[:toc_status]]
          t.save!
        else # check for update since form was issued
          # reject update, provide diff and fresh editbox
          @diff = Diffy::Diff.new(params[:markdown], @author.toc.toc)
          @rejected_update = params[:markdown]
        end
      end
      prep_toc
      prep_edit_toc
    end
  end

  def manage_toc
    @author = Authority.find(params[:id])
    prep_manage_toc
    prep_toc
    @nonce = 'top'
    @page_title = "#{t(:edit_toc)}: #{@author.name}"
  end

  def kwic
    unless @author.published_manifestations.any?
      flash[:error] = t(:no_works_for_author)
      redirect_to authority_path(@author)
      return
    end

    @page_title = "#{t(:kwic_concordance)} - #{@author.name} - #{t(:default_page_title)}"
    @pagetype = :author
    @entity = @author
    @entity_type = 'Authority'

    # Use fresh downloadable mechanism to ensure KWIC downloadable exists
    dl = ensure_kwic_downloadable_exists(@author)

    # Check if concordance is being generated asynchronously
    if dl.nil?
      flash[:notice] = t(:kwic_being_generated)
      redirect_to authority_path(@author)
      return
    end

    # Parse concordance data from the stored downloadable
    if dl&.stored_file&.attached?
      kwic_text = dl.stored_file.download.force_encoding('UTF-8')
      @concordance_data = ParseKwicConcordance.call(kwic_text)

      # Enrich instances with manifestation IDs for context fetching
      # Map labels to manifestation IDs
      @manifestations_by_label = {}
      @author.published_manifestations.each do |m|
        @manifestations_by_label[m.title] = m.id
      end

      @concordance_data.each do |entry|
        entry[:instances].each do |instance|
          instance[:manifestation_id] = @manifestations_by_label[instance[:label]]
        end
      end
    else
      # This shouldn't happen since ensure_kwic_downloadable_exists returns nil for async generation
      flash[:error] = t(:error_generating_concordance)
      redirect_to authority_path(@author)
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
    @concordance_data = sort_concordance_data(@concordance_data, @sort_by)

    # Pagination
    @total_entries = @concordance_data.length
    @page = (params[:page] || 1).to_i
    @page = 1 if @page < 1
    @total_pages = (@total_entries.to_f / @per_page).ceil
    @page = @total_pages if @page > @total_pages && @total_pages > 0

    start_idx = (@page - 1) * @per_page
    end_idx = start_idx + @per_page - 1
    @concordance_entries = @concordance_data[start_idx..end_idx] || []
  end

  def kwic_download
    unless @author.published_manifestations.any?
      flash[:error] = t(:no_works_for_author)
      redirect_to authority_path(@author)
      return
    end

    # Use fresh downloadable mechanism to ensure KWIC downloadable exists
    dl = ensure_kwic_downloadable_exists(@author)

    # Check if concordance is being generated asynchronously
    if dl.nil?
      flash[:notice] = t(:kwic_being_generated)
      redirect_to authority_path(@author)
      return
    end

    # Parse concordance data from the stored downloadable
    if dl&.stored_file&.attached?
      kwic_text = dl.stored_file.download.force_encoding('UTF-8')
      @concordance_data = ParseKwicConcordance.call(kwic_text)
    else
      # This shouldn't happen since ensure_kwic_downloadable_exists returns nil for async generation
      flash[:error] = t(:error_generating_concordance)
      redirect_to authority_path(@author)
      return
    end

    # Apply filter if present
    @filter_text = params[:filter].to_s.strip
    if @filter_text.present?
      @concordance_data = @concordance_data.select do |entry|
        entry[:token].include?(@filter_text)
      end
    end

    # Apply sort
    @sort_by = params[:sort].to_s.strip
    @sort_by = 'alphabetical' unless %w(alphabetical frequency).include?(@sort_by)
    @concordance_data = sort_concordance_data(@concordance_data, @sort_by)

    # Format as text
    content = format_concordance_as_text(@concordance_data)

    # Send as downloadable file
    filename = "#{@author.name.gsub(/[^0-9א-תA-Za-z.\-]/, '_')}_kwic.txt"
    send_data content, filename: filename, type: 'text/plain; charset=utf-8', disposition: 'attachment'
  end

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

  protected

  def set_author
    @author = Authority.find(params[:id])
  end

  def authority_params
    params.require(:authority).permit(
      :comment,
      :country,
      :name,
      :nli_id,
      :other_designation,
      :viaf_id,
      :intellectual_property,
      :profile_image,
      :wikidata_uri,
      :wikipedia_url,
      :wikipedia_snippet,
      :blog_category_url,
      :profile_image,
      :bib_done,
      :do_not_feature,
      :sort_name,
      :status,
      :legacy_credits,
      person_attributes: %i(id gender period birthdate deathdate),
      corporate_body_attributes: %i(id location inception inception_year dissolution dissolution_year)
    )
  end

  def prep_for_print
    if @author.nil?
      head :ok
    else
      track_view(@author)

      @page_title = "#{@author.name} - #{t(:author_table_of_contents)} - #{t(:project_ben_yehuda)}"
      unless @author.toc.nil?
        prep_toc
      else
        generate_toc
      end
    end
  end

  private

  # Calculate manifestation counts for each role and section (collection_level, work_level, uncollected)
  # This is called once in the controller to avoid duplicate calculations in navbar and TOC body
  def calculate_toc_counts(toc_tree, authority_id)
    counts = {}

    InvolvedAuthority::ROLES_PRESENTATION_ORDER.each do |role|
      top_nodes = toc_tree.top_level_nodes

      involved_on_collection_level = top_nodes.select { |node| node.visible?(role, authority_id, true) }
                                              .sort_by(&:sort_term)
      involved_on_work_level = top_nodes.select { |node| node.visible?(role, authority_id, false) }
                                        .sort_by(&:sort_term)
      uncollected_node = involved_on_work_level.detect { |node| node.collection.uncollected? }
      involved_on_work_level -= [uncollected_node] if uncollected_node.present?

      collection_level_count = involved_on_collection_level.sum do |node|
        node.count_manifestations(role, authority_id, true)
      end

      work_level_count = involved_on_work_level.sum do |node|
        node.count_manifestations(role, authority_id, false)
      end

      uncollected_count = if uncollected_node&.visible?(role, authority_id, false)
                            uncollected_node.count_manifestations(role, authority_id, false)
                          else
                            0
                          end

      total_count = collection_level_count + work_level_count + uncollected_count

      counts[role] = {
        collection_level: collection_level_count,
        work_level: work_level_count,
        uncollected: uncollected_count,
        total: total_count
      }
    end

    counts
  end
end
