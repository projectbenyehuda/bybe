TAGGING_LOCK = '/tmp/tagging.lock'
TAGGING_LOCK_TIMEOUT = 15 # 15 minutes
PROGRESS_SERIES = [5, 10, 25, 50, 75, 100, 150, 200, 300, 400, 500, 750, 1000, 1250, 1500, 2000, 3000, 4000, 5000,
                   10_000]

class AdminController < ApplicationController
  before_action :require_editor
  before_action :obtain_tagging_lock,
                only: %i(approve_tag approve_tag_and_next reject_tag escalate_tag reject_tag_and_next merge_tag
                         merge_tagging approve_tagging reject_tagging escalate_tagging tag_moderation tag_review
                         undo_reject_tag undo_approve_tagging undo_reject_tagging)
  before_action :require_admin, only: %i(manifestation_batch_tools destroy_manifestation unpublish_manifestation)
  # before_action :require_admin, only: [:missing_languages, :missing_genres, :incongruous_copyright, :missing_copyright, :similar_titles]
  autocomplete :person, :name, scopes: :with_name, full: true
  autocomplete :collection, :title, full: true, display_value: :title_and_authors
  autocomplete :publication, :title

  layout false, only: %i(merge_tag merge_tagging confirm_with_comment) # popups
  layout 'backend', only: %i(tag_moderation tag_review tagging_review edit_tag) # eventually change to except: [<popups>]

  def index
    return unless current_user && current_user.editor?

    if current_user.has_bit?('handle_proofs')
      @open_proofs = Proof.where(status: 'new').count.to_s
      @escalated_proofs = Proof.where(status: 'escalated').count.to_s
    end
    if current_user.has_bit?('edit_catalog')
      @current_uploads = HtmlFile.where(assignee: current_user, status: 'Uploaded')
    end
    if current_user.has_bit?('edit_people')
      @ingestibles_pending = Ingestible.where(status: 'awaiting_authorities')
    end
    if current_user.has_bit?('moderate_tags')
      @pending_tags = Tag.where(status: :pending).with_taggings.count
      @pending_taggings = Tagging.where(status: :pending).count
    end
    @open_recommendations = LegacyRecommendation.where(status: 'new').count.to_s
    @conv_todo = Manifestation.where(conversion_verified: false, status: Manifestation.statuses[:published]).count
    @manifestation_count = Manifestation.published.count
    @conv_percent_done = (@manifestation_count - @conv_todo) / @manifestation_count.to_f * 100
    @page_title = t(:dashboard)
    @search = SiteWideSearch.new(query: '')
  end

  def autocomplete_authority_name_and_aliases
    items = ElasticsearchAutocomplete.call(
      params[:term],
      AuthoritiesAutocompleteIndex,
      %i(name other_designation)
    )

    render json: json_for_autocomplete(items, :name)
  end

  def autocomplete_manifestation_title
    items = ElasticsearchAutocomplete.call(
      params[:term],
      ManifestationsAutocompleteIndex,
      %i(title alternate_titles)
    )

    render json: json_for_autocomplete(items, :title_and_authors, [:expression_id])
  end

  ##############################################
  ## Reports
  def raw_tocs
    @authors = Person.joins(:toc).where('tocs.status = 0').page(params[:page]).per(15)
    @total = Person.joins(:toc).where('tocs.status = 0').count
    @page_title = t(:raw_tocs)
    Rails.cache.write('report_raw_tocs', @total)
  end

  def messy_tocs
    @authors = []
    Person.has_toc.joins(:toc).includes(:toc).each do |p|
      unless p.toc.structure_okay?
        @authors << p
      end
    end
    Rails.cache.write('report_messy_tocs', @authors.count)
  end

  def missing_languages
    ex = Expression.joins(%i(involved_authorities work))
                   .where(works: { orig_lang: :he })
                   .merge(InvolvedAuthority.role_translator)
    mans = ex.map { |e| e.manifestations[0] }
    @total = mans.length
    @mans = Kaminari.paginate_array(mans).page(params[:page]).per(50)
    @page_title = t(:missing_language_report)
    Rails.cache.write('report_missing_languages', mans.length)
  end

  def missing_genres
    missing_genres = Manifestation.genre(nil)
    @mans = missing_genres.page(params[:page]).per(50)
    @total = missing_genres.count
    @page_title = t(:missing_genre_report)
    Rails.cache.write('report_missing_genres', @total)
  end

  def missing_images
    @authors = Person.where(profile_image_file_name: nil).order('name asc')
    @page_title = t(:missing_images)
    Rails.cache.write('report_missing_images', @authors.count)
  end

  def missing_copyright
    @authors = Authority.intellectual_property_unknown
    records = Manifestation.joins(:expression).merge(Expression.intellectual_property_unknown)
    @total = records.count
    @mans = records.page(params[:page]).per(50)
    @page_title = t(:missing_copyright_report)
    Rails.cache.write('report_missing_copyright', @total)
  end

  def similar_titles
    prefixes = {}
    @similarities = {}
    whitelisted_ids = ListItem.where(listkey: 'similar_title_whitelist').pluck(:item_id)
    Manifestation.all.each do |m|
      next if whitelisted_ids.include?(m.id) # skip whitelisted works

      prefix = [m.cached_people, m.title[0..(m.title.length > 8 ? 8 : -1)]]
      if prefixes[prefix].nil?
        prefixes[prefix] = [m]
      else
        prefixes[prefix] << m
      end
    end
    prefixes.each_pair do |k, v|
      next if v.length < 2

      @similarities[k] = v.sort_by { |m| m.title }
    end
    Rails.cache.write('report_similar_titles', @similarities.keys.length)
  end

  def mark_similar_as_valid
    m = Manifestation.find(params[:id])
    unless m.nil?
      li = ListItem.new(listkey: 'similar_title_whitelist', item: m)
      li.save!
    end
    head :ok
  end

  # Find works where the author is also a translator -- this *may* be okay, in the case of self-translation,
  # but probably is a mistake
  def suspicious_translations
    records = Manifestation.joins(expression: { work: :involved_authorities })
                           .merge(InvolvedAuthority.role_author)
                           .where(
                             <<~SQL.squish,
                               exists (
                                 select 1 from
                                   involved_authorities iat
                                 where
                                   iat.item_id = expressions.id
                                   and iat.item_type = 'Expression'
                                   and iat.authority_id = involved_authorities.authority_id
                                   and iat.role = ?
                               )
                             SQL
                             InvolvedAuthority.roles[:translator]
                           )
    @total = records.count
    @mans = records.page(params[:page])
    @page_title = t(:suspicious_translations_report)
    Rails.cache.write('report_suspicious_translations', @total)
  end

  # Find Expressions by different translators with the same title, whose Works are by the same author
  # These likely represent different translations that should be merged under a single Work record
  def duplicate_works
    # Find expressions grouped by work author and expression title
    # where there are multiple expressions with different translators
    duplicate_clusters = {}

    # Get all expressions that are translations
    # We need to include involved_authorities for translators
    Expression.includes(:work, :involved_authorities, work: [:involved_authorities])
              .where(translation: true)
              .find_each do |expr|
      # Skip if work has no author or expression has no translators
      next if expr.work.authors.empty? || expr.translators.empty?

      # Create a key from work's first author and expression title
      key = [expr.work.authors.first.id, expr.title]

      duplicate_clusters[key] ||= []
      duplicate_clusters[key] << expr
    end

    # Filter to only include clusters with multiple expressions by different translators
    @duplicate_clusters = duplicate_clusters.select do |_key, expressions|
      next false if expressions.length < 2

      # Check that translators are different
      translator_ids = expressions.flat_map { |e| e.translators.map(&:id) }.uniq
      translator_ids.length > 1
    end

    # Sort by author name for consistent display
    @duplicate_clusters = @duplicate_clusters.sort_by do |key, _expressions|
      author = Authority.find(key[0])
      author.name
    end.to_h

    @total = @duplicate_clusters.keys.length
    @page_title = t(:duplicate_works_report)
    Rails.cache.write('report_duplicate_works', @total)
  end

  def merge_works
    @source_work_id = params[:source_work_id]
    @target_work_id = params[:target_work_id]

    source_work = Work.find(@source_work_id)
    target_work = Work.find(@target_work_id)

    # Use a transaction to ensure atomicity
    ActiveRecord::Base.transaction do
      # Reassociate expressions from source to target BEFORE destroying
      source_work.expressions.update_all(work_id: @target_work_id)

      # Reassociate aboutnesses where this work is ABOUT something (topics)
      # These are Aboutness records where work_id = source_work_id
      Aboutness.where(work_id: @source_work_id).update_all(work_id: @target_work_id)

      # Reassociate aboutnesses where OTHER works are ABOUT this work
      # These are Aboutness records where aboutable_id = source_work_id and aboutable_type = 'Work'
      Aboutness.where(aboutable_type: 'Work', aboutable_id: @source_work_id)
              .update_all(aboutable_id: @target_work_id)

      # Reload source work to get updated associations, then destroy
      source_work.reload
      source_work.destroy!
    end

    @success = true
    @message = t(:works_merged_successfully)

    respond_to do |format|
      format.html { redirect_to action: :duplicate_works, notice: @message }
      format.js
    end
  rescue ActiveRecord::RecordNotFound
    @success = false
    @message = t(:work_not_found)
    respond_to do |format|
      format.html { redirect_to action: :duplicate_works, alert: @message }
      format.js
    end
  rescue StandardError => e
    @success = false
    @message = t(:merge_failed, error: e.message)
    respond_to do |format|
      format.html { redirect_to action: :duplicate_works, alert: @message }
      format.js
    end
  end

  def assign_proofs
    p = Proof.where(status: 'new').order(created_at: :asc).first
    if p.nil?
      flash[:notice] = t(:no_more_items)
    else
      proofs_by_item = Proof.where(status: 'new', item: p.item)
      proofs_by_item.each do |proof|
        proof.status = 'assigned'
        proof.save!
        ListItem.create!(listkey: 'proofs_by_user', user: current_user, item: proof)
      end
    end
    redirect_to url_for(action: :index)
  end

  def assign_conversion_verification
    @m = Manifestation.where(conversion_verified: false,
                             status: Manifestation.statuses[:published]).order('RAND()').first
    if @m.conv_counter.nil?
      @m.conv_counter = 1
    else
      @m.conv_counter += 1
    end
    @m.save!
    li = ListItem.new(listkey: 'convs_by_user', user: current_user, item: @m)
    li.save!

    redirect_to url_for(controller: :manifestation, action: :edit, id: @m.id)
  end

  def conversion_verification
    @manifestations = Manifestation.where(conversion_verified: false).order(:title).page(params[:page])
    @total = Manifestation.where(conversion_verified: false).count
    @page_title = t(:conversion_verification_report)
    Rails.cache.write('report_conversion_verification', @total)
  end

  def my_convs
    @u = User.find(params[:id])
    if @u.nil?
      flash[:error] = t(:no_such_user)
      redirect_to action: :index
    else
      @items = ListItem.where(listkey: 'convs_by_user', user: @u)
    end
    render layout: false
  end

  def periodless
    @authors = Authority.joins(:person).merge(Person.where(period: nil)).select(&:any_hebrew_works?)
    Rails.cache.write('report_periodless', @authors.length)
  end

  def authors_without_works
    @authors = Authority.where(
      'not exists (select 1 from involved_authorities ia where ia.authority_id = authorities.id)'
    ).order(:name)
    Rails.cache.write('report_authors_without_works', @authors.length)
  end

  # this is a massive report that takes a long time to run!
  def tocs_missing_links
    @author_keys = []
    @tocs_missing_links = {}
    @tocs_linking_to_missing_items = {}
    Authority.has_toc.each do |p|
      # it may already exist because of being translated by an author we've already processed
      @tocs_missing_links[p.id] = { orig: [], xlat: [] } if @tocs_missing_links[p.id].nil?
      toc_items = []
      begin
        toc_items = p.toc.linked_items
      rescue ActiveRecord::RecordNotFound
        @tocs_linking_to_missing_items[p.id] = []
        found_item_ids = []
        p.toc.linked_item_ids.each do |mid|
          if Manifestation.exists?(mid)
            found_item_ids << mid
          else
            @tocs_linking_to_missing_items[p.id] << mid
          end
        end
        toc_items = Manifestation.find(found_item_ids)
      end
      p.original_works.each do |m|
        @tocs_missing_links[p.id][:orig] << m unless toc_items.include?(m)
      end
      p.translations.includes(expression: :work).each do |m|
        @tocs_missing_links[p.id][:xlat] << m unless toc_items.include?(m)
        # additionally, make sure they appear in the original author's ToC, if it's a manual one (relevant for translated authors who *also* wrote in Hebrew, e.g. Y. L. Perets)
        m.expression.work.authors.each do |au|
          if !au.toc.nil? && !au.toc.linked_item_ids.include?(m.id)
            @tocs_missing_links[au.id] = { orig: [], xlat: [] } if @tocs_missing_links[au.id].nil?
            @tocs_missing_links[au.id][:orig] << m
          end
        end
      end
      unless @tocs_missing_links[p.id][:orig] == [] && @tocs_missing_links[p.id][:xlat] == []
        @author_keys << p.id
      end
    end
    Rails.cache.write('report_tocs_missing_links', @author_keys.length)
  end

  def translated_from_multiple_languages
    @authors = []

    # Getting list of authors, who wrote works in more than one language
    translatees = Authority.joins(:involved_authorities)
                           .joins(
                             'join works on involved_authorities.item_id = works.id ' \
                             "and involved_authorities.item_type = 'Work'"
                           )
                           .merge(InvolvedAuthority.role_author)
                           .group('authorities.id')
                           .select('authorities.id, authorities.name')
                           .having('min(works.orig_lang) <> max(works.orig_lang)')
                           .sort_by(&:name)

    translatees.each do |t|
      manifestations = Manifestation.joins(expression: { work: :involved_authorities })
                                    .merge(InvolvedAuthority.role_author.where(authority_id: t.id))
                                    .preload(expression: :work)
                                    .sort_by { |m| [m.expression.work.orig_lang, m.sort_title] }
                                    .group_by { |m| m.expression.work.orig_lang }
      @authors << [t, manifestations.keys, manifestations]
    end
    Rails.cache.write('report_translated_from_multiple_languages', @authors.length)
  end

  PUBLIC_DOMAIN_TYPE = Authority.intellectual_properties['public_domain']

  HAS_NON_PUBLIC_DOMAIN_AUTHORITY = <<~SQL.squish
    (
      exists (
        select 1 from
          authorities a
          join involved_authorities ia on a.id = ia.authority_id
        where
          ia.item_id = works.id
          and ia.item_type = 'Work'
          and a.intellectual_property <> #{PUBLIC_DOMAIN_TYPE}
      )
      or exists (
        select 1 from
          authorities a
          join involved_authorities ia on a.id = ia.authority_id
        where
          ia.item_id = expressions.id
          and ia.item_type = 'Expression'
          and a.intellectual_property <> #{PUBLIC_DOMAIN_TYPE}
      )
    )
  SQL

  def incongruous_copyright
    @incong = Manifestation.joins(expression: :work)
                           .with_involved_authorities
                           .select('expressions.id as expression_id, expressions.intellectual_property')
                           .select('manifestations.title, manifestations.id as id')
                           .select(Arel.sql("#{HAS_NON_PUBLIC_DOMAIN_AUTHORITY} as has_non_pd_authority"))
                           .where(
                             <<~SQL.squish
                               (
                                 expressions.intellectual_property <> #{PUBLIC_DOMAIN_TYPE}
                                 and not #{HAS_NON_PUBLIC_DOMAIN_AUTHORITY}
                               ) or (
                                 expressions.intellectual_property = #{PUBLIC_DOMAIN_TYPE}
                                 and #{HAS_NON_PUBLIC_DOMAIN_AUTHORITY}
                               )
                             SQL
                           )
    Rails.cache.write('report_incongruous_copyright', @incong.length)
  end

  def texts_between_dates
    return unless params[:from].present? && params[:to].present?

    @texts = Manifestation.published.where('created_at > ? and created_at < ?', Date.parse(params[:from]),
                                           Date.parse(params[:to])).order(:created_at)
    @total = @texts.count
  end

  def authority_records_between_dates
    return unless params[:from].present? && params[:to].present?

    @records = Authority.where('created_at > ? and created_at < ?', Date.parse(params[:from]),
                               Date.parse(params[:to])).order(:created_at)
    @total = @records.count
  end

  def first_manifestations_between_dates
    return unless params[:from].present? && params[:to].present?

    from_date = Date.parse(params[:from])
    to_date = Date.parse(params[:to])

    # Step 1: Get all published manifestations within the date range
    manifestations_in_range = Manifestation.published
                                          .where('created_at >= ? AND created_at <= ?', from_date, to_date)
                                          .includes(expression: { work: :involved_authorities, involved_authorities: :authority })

    # Step 2: Extract unique authorities from these manifestations
    authority_ids_in_range = []
    manifestations_in_range.each do |m|
      authority_ids_in_range.concat(m.involved_authorities.map(&:authority_id))
    end
    authority_ids_in_range.uniq!

    # Step 3: For each authority, check if the manifestation in range is their first
    authorities_with_first_manifestations = []

    Authority.where(id: authority_ids_in_range).find_each do |authority|
      first_manifestation = authority.published_manifestations.order(:created_at).first
      next if first_manifestation.nil?

      # Check if first manifestation was created within the date range (using exclusive bounds for consistency)
      if first_manifestation.created_at > from_date && first_manifestation.created_at < to_date
        authorities_with_first_manifestations << [authority, first_manifestation]
      end
    end

    # Sort by first manifestation date
    @authorities = authorities_with_first_manifestations.sort_by { |_authority, manifestation| manifestation.created_at }
    @total = @authorities.count
  end

  def suspicious_titles
    @suspicious = Manifestation.where('(title like "%קבוצה %") OR (title like "%.")').reject { |x| x.title =~ /\.\.\./ }
    Rails.cache.write('report_suspicious_titles', @suspicious.length)
  end

  def suspicious_headings
    mm = Manifestation.where('length(cached_heading_lines)>3')
    @suspicious = []
    mm.each do |m|
      suspicious = false
      prev = -10
      m.cached_heading_lines.split('|').each do |l|
        line_no = l.to_i
        if line_no - prev < 5
          lines = m.markdown.split("\n")
          if lines[prev..line_no].join.length < 500 # probably too short for separate chapter/section
            suspicious = true
          end
        end
        prev = line_no
      end
      @suspicious << m if suspicious
    end
    Rails.cache.write('report_suspicious_headings', @suspicious.length)
  end

  def slash_in_titles
    whitelisted_ids = ListItem.where(listkey: 'title_slashes_okay').pluck(:item_id, :item_type)
    whitelisted_collections = whitelisted_ids.select { |_, type| type == 'Collection' }.map(&:first)
    whitelisted_works = whitelisted_ids.select { |_, type| type == 'Work' }.map(&:first)
    whitelisted_expressions = whitelisted_ids.select { |_, type| type == 'Expression' }.map(&:first)
    whitelisted_manifestations = whitelisted_ids.select { |_, type| type == 'Manifestation' }.map(&:first)

    @collections = Collection.where('title like ? OR title like ?', '%/%', '%\\\\%')
                             .where.not(id: whitelisted_collections)
                             .limit(25)
    @works = Work.where('title like ? OR title like ?', '%/%', '%\\\\%')
                 .where.not(id: whitelisted_works)
                 .limit(25)
    @expressions = Expression.where('title like ? OR title like ?', '%/%', '%\\\\%')
                             .where.not(id: whitelisted_expressions)
                             .limit(25)
    @manifestations = Manifestation.where('title like ? OR title like ?', '%/%', '%\\\\%')
                                   .where.not(id: whitelisted_manifestations)
                                   .limit(25)
    @total = @collections.count + @works.count + @expressions.count + @manifestations.count
    Rails.cache.write('report_slash_in_titles', @total)
  end

  def mark_slash_title_as_okay
    item_type = params[:item_type]
    item_id = params[:id]

    item = case item_type
           when 'Collection'
             Collection.find_by(id: item_id)
           when 'Work'
             Work.find_by(id: item_id)
           when 'Expression'
             Expression.find_by(id: item_id)
           when 'Manifestation'
             Manifestation.find_by(id: item_id)
           end

    unless item.nil?
      li = ListItem.new(listkey: 'title_slashes_okay', item: item)
      li.save!
    end
    head :ok
  end

  #######################################
  ## Static pages management
  def static_pages_list
    @vps = StaticPage.page(params[:page])
  end

  def static_page_new
    @vp = StaticPage.new
    respond_to do |format|
      format.html
      format.json { render json: @vp }
    end
  end

  def static_page_create
    @vp = StaticPage.new(sp_params)
    respond_to do |format|
      if @vp.save
        @vp.images.attach(params[:static_page][:images]) if params[:static_page][:images].present?
        format.html { redirect_to url_for(action: :static_page_show, id: @vp.id), notice: t(:updated_successfully) }
        format.json { render json: @vp, status: :created, location: @vp }
      else
        format.html { render action: 'static_page_new' }
        format.json { render json: @vp.errors, status: :unprocessable_content }
      end
    end
  end

  def static_page_show
    @vp = StaticPage.find(params[:id])
    if @vp.nil?
      flash[:error] = I18n.t(:no_such_item)
      redirect_to url_for(action: :index)
    end
    @markdown = @vp.prepare_markdown
  end

  def static_page_edit
    @vp = StaticPage.find(params[:id])
  end

  def static_page_update
    @vp = StaticPage.find(params[:id])
    if @vp.nil?
      flash[:error] = I18n.t(:no_such_item)
      redirect_to url_for(action: :index)
    elsif @vp.update(sp_params)
      @vp.images.attach(params[:static_page][:images]) if params[:static_page][:images].present?
      flash[:notice] = I18n.t(:updated_successfully)
      redirect_to action: :static_page_show, id: @vp.id
    else
      format.html { render action: 'static_page_edit' }
      format.json { render json: @vp.errors, status: :unprocessable_content }
    end
  end

  #######################################
  ## Volunteer profiles management
  def volunteer_profiles_list
    @vps = VolunteerProfile.page(params[:page])
  end

  def volunteer_profile_new
    @vp = VolunteerProfile.new
    respond_to do |format|
      format.html
      format.json { render json: @vp }
    end
  end

  def volunteer_profile_create
    @vp = VolunteerProfile.new(vp_params)
    respond_to do |format|
      if @vp.save
        format.html do
          redirect_to url_for(action: :volunteer_profile_show, id: @vp.id), notice: t(:updated_successfully)
        end
        format.json { render json: @vp, status: :created, location: @vp }
      else
        format.html { render action: 'volunteer_profile_new' }
        format.json { render json: @vp.errors, status: :unprocessable_content }
      end
    end
  end

  def volunteer_profile_show
    @vp = VolunteerProfile.find(params[:id])
    return unless @vp.nil?

    flash[:error] = I18n.t(:no_such_item)
    redirect_to url_for(action: :index)
  end

  def volunteer_profile_edit
    @vp = VolunteerProfile.find(params[:id])
  end

  def volunteer_profile_update
    @vp = VolunteerProfile.find(params[:id])
    if @vp.nil?
      flash[:error] = I18n.t(:no_such_item)
      redirect_to url_for(action: :index)
    elsif @vp.update(vp_params)
      flash[:notice] = I18n.t(:updated_successfully)
      redirect_to action: :volunteer_profile_show, id: @vp.id
    else
      format.html { render action: 'volunteer_profile_edit' }
      format.json { render json: @vp.errors, status: :unprocessable_content }
    end
  end

  def volunteer_profile_add_feature
    return if params[:fromdate].nil? or params[:todate].nil?

    vp = VolunteerProfile.find(params[:vpid])
    unless vp.nil?
      vpf = VolunteerProfileFeature.new(fromdate: Date.new(params[:fromdate][:year].to_i, params[:fromdate][:month].to_i, params[:fromdate][:day].to_i),
                                        todate: Date.new(params[:todate][:year].to_i,
                                                         params[:todate][:month].to_i, params[:todate][:day].to_i))
      vpf.volunteer_profile = vp
      vpf.save!

      flash[:notice] = I18n.t(:created_successfully)
      redirect_to url_for(action: :volunteer_profile_show, id: params[:vpid].to_i)
    else
      flash[:error] = I18n.t(:no_such_item)
      redirect_to url_for(action: :index)
    end
  end

  def volunteer_profile_delete_feature
    vpf = VolunteerProfileFeature.find(params[:id])
    unless vpf.nil?
      vpid = vpf.volunteer_profile_id
      vpf.destroy!
      flash[:notice] = I18n.t(:deleted_successfully)
      redirect_to url_for(action: :volunteer_profile_show, id: vpid)
    else
      flash[:error] = I18n.t(:no_such_item)
      redirect_to url_for(action: :index)
    end
  end

  def volunteer_profile_destroy
    @vp = VolunteerProfile.find(params[:id])
    unless @vp.nil?
      @vp.destroy
    end
    flash[:notice] = I18n.t(:deleted_successfully)
    redirect_to action: :volunteer_profile_list
  end

  ## sitenotices
  def sitenotice_list
    @sns = Sitenotice.page(params[:page])
  end

  def sitenotice_new
    @sn = Sitenotice.new
    respond_to do |format|
      format.html
      format.json { render json: @sn }
    end
  end

  def sitenotice_create
    @sn = Sitenotice.new(body: sn_params[:body], status: (sn_params[:status] == '1' ? :enabled : :disabled))
    @sn.fromdate = Date.new(params[:fromdate][:year].to_i, params[:fromdate][:month].to_i, params[:fromdate][:day].to_i)
    @sn.todate = Date.new(params[:todate][:year].to_i, params[:todate][:month].to_i, params[:todate][:day].to_i)
    respond_to do |format|
      if @sn.save
        Rails.cache.delete('sitenotices') # clear cached sitenotices
        format.html { redirect_to url_for(action: :sitenotice_show, id: @sn.id), notice: t(:updated_successfully) }
        format.json { render json: @sn, status: :created, location: @sn }
      else
        format.html { render action: 'sitenotice_new' }
        format.json { render json: @sn.errors, status: :unprocessable_content }
      end
    end
  end

  def sitenotice_show
    @sn = Sitenotice.find(params[:id])
    return unless @sn.nil?

    flash[:error] = I18n.t(:no_such_item)
    redirect_to url_for(action: :index)
  end

  def sitenotice_edit
    @sn = Sitenotice.find(params[:id])
  end

  def sitenotice_update
    @sn = Sitenotice.find(params[:id])
    @sn.body = sn_params[:body]
    @sn.status = (sn_params[:status] == '1' ? :enabled : :disabled)
    @sn.fromdate = Date.new(params[:fromdate][:year].to_i, params[:fromdate][:month].to_i, params[:fromdate][:day].to_i)
    @sn.todate = Date.new(params[:todate][:year].to_i, params[:todate][:month].to_i, params[:todate][:day].to_i)
    if @sn.nil?
      flash[:error] = I18n.t(:no_such_item)
      redirect_to url_for(action: :index)
    elsif @sn.save
      Rails.cache.delete('sitenotices') # clear cached sitenotices
      flash[:notice] = I18n.t(:updated_successfully)
      redirect_to action: :sitenotice_show, id: @sn.id
    else
      format.html { render action: 'sitenotice_edit' }
      format.json { render json: @sn.errors, status: :unprocessable_content }
    end
  end

  def sitenotice_destroy
    @sn = Sitenotice.find(params[:id])
    unless @sn.nil?
      @sn.destroy
      Rails.cache.delete('sitenotices') # clear cached sitenotices
    end
    flash[:notice] = I18n.t(:deleted_successfully)
    redirect_to action: :sitenotice_list
  end

  ########################################################
  ## featured author
  def featured_author_list
    @fcs = FeaturedAuthor.page(params[:page])
  end

  def featured_author_new
    @fc = FeaturedAuthor.new
    respond_to do |format|
      format.html
      format.json { render json: @fc }
    end
  end

  def featured_author_create
    @fc = FeaturedAuthor.new(fa_params)
    @fc.person_id = params[:person_id]
    @fc.user = current_user
    respond_to do |format|
      if @fc.save
        format.html { redirect_to url_for(action: :featured_author_show, id: @fc.id), notice: t(:updated_successfully) }
        format.json { render json: @fc, status: :created, location: @fc }
      else
        format.html { render action: 'featured_author_new' }
        format.json { render json: @fc.errors, status: :unprocessable_content }
      end
    end
  end

  def featured_author_show
    @fc = FeaturedAuthor.find(params[:id])
    return unless @fc.nil?

    flash[:error] = I18n.t(:no_such_item)
    redirect_to url_for(action: :index)
  end

  def featured_author_edit
    @fc = FeaturedAuthor.find(params[:id])
  end

  def featured_author_destroy
    @fa = FeaturedAuthor.find(params[:id])
    unless @fa.nil?
      @fa.destroy
    end
    flash[:notice] = I18n.t(:deleted_successfully)
    redirect_to action: :featured_author_list
  end

  def featured_author_update
    @fc = FeaturedAuthor.find(params[:id])
    if @fc.nil?
      flash[:error] = I18n.t(:no_such_item)
      redirect_to url_for(action: :index)
    elsif @fc.update(fa_params)
      flash[:notice] = I18n.t(:updated_successfully)
      redirect_to action: :featured_author_show, id: @fc.id
    else
      format.html { render action: 'featured_author_edit' }
      format.json { render json: @fc.errors, status: :unprocessable_content }
    end
  end

  def featured_author_add_feature
    return if params[:fromdate].nil? or params[:todate].nil?

    fc = FeaturedAuthor.find(params[:fcid])
    unless fc.nil?
      fcf = FeaturedAuthorFeature.new(fromdate: Date.new(params[:fromdate][:year].to_i, params[:fromdate][:month].to_i, params[:fromdate][:day].to_i),
                                      todate: Date.new(params[:todate][:year].to_i,
                                                       params[:todate][:month].to_i, params[:todate][:day].to_i))
      fcf.featured_author = fc
      fcf.save!

      flash[:notice] = I18n.t(:created_successfully)
      redirect_to url_for(action: :featured_author_show, id: fc.id)
    else
      flash[:error] = I18n.t(:no_such_item)
      redirect_to url_for(action: :index)
    end
  end

  def featured_author_delete_feature
    fcf = FeaturedAuthorFeature.find(params[:id])
    unless fcf.nil?
      fcid = fcf.featured_author_id
      fcf.destroy!
      flash[:notice] = I18n.t(:deleted_successfully)
      redirect_to url_for(action: :featured_author_show, id: fcid)
    else
      flash[:error] = I18n.t(:no_such_item)
      redirect_to url_for(action: :index)
    end
  end

  ########################################################
  # user content moderation
  def tag_moderation
    require_editor('moderate_tags')
    @header_partial = 'tagmod_top'
    status_to_query = if current_user.admin?
                        %i(pending escalated)
                      else
                        :pending
                      end
    @pending_tags = Tag.includes(:taggings).where(status: status_to_query).where('COALESCE(taggings_count, 0) > 0').distinct.order(:created_at)
    if params[:tag_id].present?
      @tag_id = params[:tag_id].to_i
      @tag = Tag.find(@tag_id)
      @pending_taggings = Tagging.joins(:tag).where(status: status_to_query,
                                                    tag_id: @tag_id).where(tag: { status: :approved }).distinct.order(:created_at)
    else
      @pending_taggings = Tagging.joins(:tag).where(status: status_to_query).where(tag: { status: :approved }).distinct.order(:created_at)
    end
    @page_title = t(:moderate_tags)
    @similar_tags = ListItem.where(listkey: 'tag_similarity').pluck(:item_id, :extra).to_h
    calculate_editor_tagging_stats
    @dashboards = true
  end

  def tag_review
    require_editor('moderate_tags')
    @header_partial = 'tagmod_top'
    @tag = Tag.find(params[:id])
    if @tag.nil?
      flash[:error] = I18n.t(:no_such_item)
      redirect_to url_for(action: :tag_moderation)
    else
      stags = ListItem.where(listkey: 'tag_similarity', item: @tag).pluck(:extra).map do |x|
                x.split(':')
              end.sort_by { |score, _tag| score }.reverse
      @similar_tags = Tag.where(id: stags.map { |x| x[1] })
      calculate_editor_tagging_stats
      @next_tag_id = Tag.where(status: :pending).where('COALESCE(taggings_count, 0) > 0').where('created_at > ?',
                                                       @tag.created_at).order(:created_at).limit(1).pluck(:id).first
      @prev_tag_id = Tag.where(status: :pending).where('COALESCE(taggings_count, 0) > 0').where('created_at < ?',
                                                       @tag.created_at).order('created_at desc').limit(1).pluck(:id).first
    end
  end

  def tagging_review
    require_editor('moderate_tags')
    @header_partial = 'tagmod_top'
    @tagging = Tagging.find(params[:id])
    if @tagging.nil?
      flash[:error] = I18n.t(:no_such_item)
      redirect_to url_for(action: :tag_moderation)
    else
      @suggester_taggings_count = @tagging.suggester.taggings.count
      @suggester_acceptance_rate = @tagging.suggester.taggings.where(status: :approved).count.to_f / @suggester_taggings_count
      calculate_editor_tagging_stats
      @next_tagging_id = Tagging.joins(:tag).where(status: :pending, tag: { status: :approved }).where(
        'taggings.created_at > ?', @tagging.created_at
      ).order('taggings.created_at').limit(1).pluck(:id).first
      @prev_tagging_id = Tagging.joins(:tag).where(status: :pending, tag: { status: :approved }).where(
        'taggings.created_at < ?', @tagging.created_at
      ).order('taggings.created_at desc').limit(1).pluck(:id).first
      if @tagging.taggable_type == 'Authority'
        @author = @tagging.taggable
        unless @author.toc.nil?
          prep_toc
        else
          generate_toc
        end
      elsif @tagging.taggable_type == 'Manifestation'
        @m = @tagging.taggable
        @html = MultiMarkdown.new(@m.markdown).to_html.force_encoding('UTF-8').gsub(%r{<figcaption>.*?</figcaption>}, '') # remove MMD's automatic figcaptions
      end
    end
  end

  def merge_tag
    require_editor('moderate_tags')
    if session[:tagging_lock]
      t = Tag.find(params[:id])
      if t.present?
        @tag = t
        if params[:with_tag].present?
          @with_tag = Tag.find(params[:with_tag].to_i)
        end
        render layout: false
      else
        head :not_found
      end
    else
      head :forbidden
    end
  end

  def do_merge_tag
    require_editor('moderate_tags')
    if session[:tagging_lock]
      t = Tag.find(params[:id])
      if t.present?
        if params[:with_tag].present?
          with_tag = Tag.find(params[:with_tag].to_i)
          if with_tag.present?
            t.merge_into(with_tag)
            Notifications.send_or_queue(:tag_merged, t.creator.email, t.name, t.creator, with_tag.name) unless t.creator.blocked? # don't send email if user is blocked
            flash[:notice] = t(:tag_merged)
          end
        elsif params[:tag].present?
          t.update(name: params[:tag], status: :approved)
          tn = t.tag_names.first
          tn.update(name: params[:tag]) # also change the TagName that was created for the proposed tag
          # Notifications.tag_renamed_and_approved(t.name, t.creator, params[:tag]).deliver unless t.creator.blocked? # don't send email if user is blocked
          Notifications.send_or_queue(:tag_rejected, t.creator.email, t, params[:reason], params[:orig_tag_name]) unless t.creator.blocked? # don't send email if user is blocked
          flash[:notice] = t(:tag_approved_with_different_name)
        else
          flash[:error] = t(:no_such_item)
        end
      else
        flash[:error] = t(:no_such_item)
      end
    else
      flash[:error] = t(:tagging_system_locked)
    end
    redirect_to url_for(action: :tag_moderation)
  end

  def edit_tag
    require_editor('moderate_tags')
    @tag = Tag.find(params[:id]) # Raises ActiveRecord::RecordNotFound if not found
    @tag_names = @tag.tag_names.order(:name)
  end

  def update_tag
    require_editor('moderate_tags')
    unless params[:id].present?
      flash[:error] = t(:no_such_item)
      redirect_to tag_moderation_path
      return
    end

    @tag = Tag.find_by(id: params[:id])
    unless @tag
      flash[:error] = t(:no_such_item)
      redirect_to tag_moderation_path
      return
    end

    update_successful = true
    primary_tag_name = nil

    # Update tag name if changed
    if params[:tag_name].present? && params[:tag_name] != @tag.name
      update_successful &&= @tag.update(name: params[:tag_name])
      # Update the primary TagName as well (the preferred name)
      # Use .order(:id) to ensure we get the first-created TagName
      primary_tag_name = @tag.tag_names.order(:id).first
      if primary_tag_name
        update_successful &&= primary_tag_name.update(name: params[:tag_name])
      end
    end

    # Update status if changed
    if params[:status].present? && params[:status] != @tag.status
      update_successful &&= @tag.update(status: params[:status])
    end

    if update_successful
      flash[:notice] = t(:tag_updated)
      redirect_to edit_tag_path(@tag)
    else
      # Collect validation errors from Tag and primary TagName (if present)
      error_messages = @tag.errors.full_messages
      if primary_tag_name && primary_tag_name.errors.any?
        error_messages.concat(primary_tag_name.errors.full_messages)
      end
      flash.now[:error] = error_messages.uniq.to_sentence
      @tag_names = @tag.tag_names.order(:name)
      render :edit_tag
    end
  end

  def add_tag_name
    require_editor('moderate_tags')
    unless params[:id].present?
      flash[:error] = t(:no_such_item)
      redirect_to tag_moderation_path
      return
    end

    @tag = Tag.find_by(id: params[:id])
    unless @tag
      flash[:error] = t(:no_such_item)
      redirect_to tag_moderation_path
      return
    end

    if params[:tag_name].present?
      # Check if tag name already exists
      existing_tag_name = TagName.find_by(name: params[:tag_name])
      if existing_tag_name
        flash[:error] = t(:tag_name_already_exists)
      else
        tag_name = @tag.tag_names.build(name: params[:tag_name])
        if tag_name.save
          flash[:notice] = t(:tag_name_added)
        else
          flash[:error] = tag_name.errors.full_messages.to_sentence
        end
      end
    else
      flash[:error] = t(:tag_name_cannot_be_blank)
    end
    redirect_to edit_tag_path(@tag)
  end

  def remove_tag_name
    require_editor('moderate_tags')
    tag_name = TagName.find(params[:id]) # Raises ActiveRecord::RecordNotFound if not found
    # Don't allow removing the last TagName
    tag = tag_name.tag
    if tag.tag_names.count <= 1
      flash[:error] = t(:cannot_remove_last_tag_name)
    else
      tag_name.destroy
      flash[:notice] = t(:tag_name_removed)
    end
    redirect_to edit_tag_path(tag)
  end

  def merge_tagging
    require_editor('moderate_tags')
    if session[:tagging_lock]
      t = Tagging.find(params[:id])
      if t.present?
        @tagging = t
        render layout: false
      else
        head :not_found
      end
    else
      head :forbidden
    end
  end

  def do_merge_tagging
    require_editor('moderate_tags')
    if session[:tagging_lock]
      t = Tagging.find(params[:id])
      if t.present?
        orig_name = t.tag.name
        with_tag = Tag.find(params[:with_tag].to_i)
        if with_tag.present?
          t.update(tag_id: with_tag.id, status: :approved)
          Notifications.send_or_queue(:tag_merged, t.suggester.email, t, orig_name, t.suggester) unless t.suggester.blocked? # don't send email if user is blocked
          flash[:notice] = t(:tagging_merged)
        else
          flash[:error] = t(:no_such_item)
        end
      else
        flash[:error] = t(:no_such_item)
      end
    else
      flash[:error] = t(:tagging_system_locked)
    end
    redirect_to url_for(action: :tag_moderation)
  end

  def approve_tag # approve tag and proceed to review taggings
    require_editor('moderate_tags')
    if session[:tagging_lock]
      t = Tag.find(params[:id])
      if t.present?
        t.approve!(current_user)
        Notifications.send_or_queue(:tag_approved, t.creator.email, t) unless t.creator.blocked? # don't send email if user is blocked
        flash[:notice] = t(:tag_approved)
        redirect_to url_for(action: :tag_moderation, tag_id: t.id)
      else
        head :not_found
      end
    else
      head :forbidden
    end
  end

  def approve_tag_and_next # to be called from tag review page (non-AJAX)
    require_editor('moderate_tags')
    if session[:tagging_lock]
      t = Tag.find(params[:id])
      if t.present?
        t.approve!(current_user)
        Notifications.send_or_queue(:tag_approved, t.creator.email, t) unless t.creator.blocked? # don't send email if user is blocked
        next_items = Tag.where(status: :pending).where('COALESCE(taggings_count, 0) > 0').where('created_at > ?', t.created_at).order(:created_at).limit(1)
        if next_items.first.present?
          redirect_to url_for(action: :tag_review, id: next_items.first.id)
        else
          flash[:notice] = t(:no_more_to_review)
          redirect_to url_for(action: :tag_moderation)
        end
      else
        head :not_found
      end
    else
      head :forbidden
    end
  end

  def reject_tag_and_next
    require_editor('moderate_tags')
    if session[:tagging_lock]
      t = Tag.find(params[:id])
      if t.present?
        t.reject!(current_user)
        # if params[:reason].present?
        Notifications.send_or_queue(:tag_rejected, t.creator.email, t, params[:reason]) unless t.creator.blocked? # don't send email if user is already blocked
        # end
        next_items = Tag.where(status: :pending).where('COALESCE(taggings_count, 0) > 0').where('created_at > ?', t.created_at).order(:created_at).limit(1)
        if next_items.first.present?
          flash[:notice] = t(:tag_rejected)
          redirect_to url_for(action: :tag_review, id: next_items.first.id)
        else
          flash[:notice] = t(:no_more_to_review)
          redirect_to url_for(action: :tag_moderation)
        end
      else
        head :not_found
      end
    else
      head :forbidden
    end
  end

  def reject_tag
    require_editor('moderate_tags')
    if session[:tagging_lock]
      t = Tag.find(params[:id])
      if t.present?
        t.reject!(current_user)
        # if params[:reason].present?
        Notifications.send_or_queue(:tag_rejected, t.creator.email, t, params[:reason]) unless t.creator.blocked? # don't send email if user is already blocked
        # end
        return render json: { tag_id: t.id, tag_name: t.name }
      else
        head :not_found
      end
    else
      head :forbidden
    end
  end

  def escalate_tag
    require_editor('moderate_tags')
    if session[:tagging_lock]
      @tag = Tag.find(params[:id])
      if @tag.present?
        @tag.escalate!(current_user)
        respond_to do |format|
          format.html do
            next_items = Tag.where(status: :pending).where('COALESCE(taggings_count, 0) > 0').where('created_at > ?',
                                                           @tag.created_at).order(:created_at).limit(1)
            if next_items.first.present?
              flash[:notice] = t(:tag_escalated)
              redirect_to url_for(action: :tag_review, id: next_items.first.id)
            else
              flash[:notice] = t(:no_more_to_review)
              redirect_to url_for(action: :tag_moderation)
            end
          end
          format.js
        end
      else
        head :not_found
      end
    else
      head :forbidden
    end
  end

  def escalate_tagging
    require_editor('moderate_tags')
    if session[:tagging_lock]
      @tagging = Tagging.find(params[:id])
      if @tagging.present?
        @tagging.escalate!(current_user)
        respond_to do |format|
          format.html { redirect_to_next_tagging(@tagging, I18n.t(:tagging_escalated)) }
          format.js
          format.json { head :ok }
        end
      else
        head :not_found
      end
    else
      head :forbidden
    end
  end

  def approve_tagging
    require_editor('moderate_tags')
    if session[:tagging_lock]
      t = Tagging.find(params[:id])
      if t.present?
        t.approve!(current_user)
        Notifications.send_or_queue(:tagging_approved, t.suggester.email, t) unless t.suggester.blocked? # don't send email if user is blocked
        respond_to do |format|
          format.html { redirect_to_next_tagging(t, I18n.t(:tagging_approved)) }
          format.json { head :ok }
        end
      else
        head :not_found
      end
    else
      head :forbidden
    end
  end

  def reject_tagging
    require_editor('moderate_tags')
    if session[:tagging_lock]
      t = Tagging.find(params[:id])
      if t.present?
        t.reject!(current_user)
        Notifications.send_or_queue(:tagging_rejected, t.suggester.email, t, params[:explanation]) unless t.suggester.blocked? # don't send email if user is blocked
        respond_to do |format|
          format.html { redirect_to_next_tagging(t, I18n.t(:tagging_rejected)) }
          format.json { head :ok }
        end
      else
        head :not_found
      end
    else
      head :forbidden
    end
  end

  def undo_reject_tag
    require_editor('moderate_tags')
    if session[:tagging_lock]
      t = Tag.find(params[:id])
      if t.present?
        t.unreject!
        render json: { tag_id: t.id, tag_name: t.name }
      else
        head :not_found
      end
    else
      head :forbidden
    end
  end

  def undo_approve_tagging
    require_editor('moderate_tags')
    if session[:tagging_lock]
      t = Tagging.find(params[:id])
      if t.present?
        t.update(status: :pending, approved_by: nil)
        render json: { tagging_id: t.id }
      else
        head :not_found
      end
    else
      head :forbidden
    end
  end

  def undo_reject_tagging
    require_editor('moderate_tags')
    if session[:tagging_lock]
      t = Tagging.find(params[:id])
      if t.present?
        t.update(status: :pending, approved_by: nil)
        render json: { tagging_id: t.id }
      else
        head :not_found
      end
    else
      head :forbidden
    end
  end

  def warn_user
    require_editor('moderate_tags') # TODO: update to a more generic editor bit
    u = User.find(params[:id])
    if u.present?
      u.warn!(params[:reason])
      flash[:notice] = t(:user_warned)
      url = params[:return_url] || url_for(action: :tag_moderation)
      redirect_to url
    else
      head :not_found
    end
  end

  def block_user
    require_editor('moderate_tags') # TODO: update to a more generic editor bit
    u = User.find(params[:id])
    if u.present?
      u.block!('tags', current_user, params[:reason])

      flash[:notice] = t(:user_blocked)
      url = params[:return_url] || url_for(action: :tag_moderation)
      redirect_to url
    else
      head :not_found
    end
  end

  def confirm_with_comment
    render partial: 'shared/confirm_with_comment',
           locals: { p1: params['p1'], with_comment: params['with_comment'], title: params['title'],
                     element_id: params['element_id'] }
  end

  def manifestation_batch_tools
    return unless params[:ids].present?

    ids = parse_manifestation_ids(params[:ids])
    @manifestations = Manifestation.where(id: ids)
  end

  def destroy_manifestation
    m = Manifestation.find(params[:id])
    m.destroy
    respond_to do |format|
      format.html do
        redirect_to manifestation_batch_tools_admin_index_path(ids: params[:ids]), notice: t(:deleted_successfully)
      end
      format.json { render json: { success: true, message: t(:deleted_successfully), id: params[:id] } }
    end
  end

  def unpublish_manifestation
    m = Manifestation.find(params[:id])
    m.update(status: 'unpublished')
    respond_to do |format|
      format.html do
        redirect_to manifestation_batch_tools_admin_index_path(ids: params[:ids]), notice: t(:updated_successfully)
      end
      format.json { render json: { success: true, message: t(:updated_successfully), id: params[:id] } }
    end
  end

  private

  def parse_manifestation_ids(input)
    ids = []
    # Split by whitespace
    input.split(/\s+/).each do |token|
      # Check if token contains a range separator (- or –)
      if token =~ /^(\d+)[-–](\d+)$/
        start_id = ::Regexp.last_match(1).to_i
        end_id = ::Regexp.last_match(2).to_i
        # Ensure start_id <= end_id; swap if necessary
        if start_id > end_id
          start_id, end_id = end_id, start_id
        end
        ids.concat((start_id..end_id).to_a)
      else
        # Single ID
        ids << token.to_i if token =~ /^\d+$/
      end
    end
    ids.uniq
  end

  def vp_params
    params[:volunteer_profile].permit(:name, :bio, :about, :profile_image)
  end

  def fa_params
    params[:featured_author].permit(:title, :body)
  end

  def sp_params
    params[:static_page].permit(:tag, :title, :body, :status, :mode, :ltr)
  end

  def sn_params
    params[:sitenotice].permit(:body, :status)
  end

  def obtain_tagging_lock
    if File.exist?(TAGGING_LOCK)
      mtime = File.mtime(TAGGING_LOCK)
      if mtime.to_i < TAGGING_LOCK_TIMEOUT.minutes.ago.to_i
        File.write(TAGGING_LOCK, "#{current_user.id}")
        session[:tagging_lock] = true
      else
        lock_owner = File.read(TAGGING_LOCK).to_i
        if lock_owner == current_user.id
          FileUtils.touch(TAGGING_LOCK) # refresh the lock
          session[:tagging_lock] = true
        else
          @tagging_lock_owner = User.find(lock_owner).name
          @tagging_lock_refreshed = ((Time.current - mtime) / 60).floor
          session[:tagging_lock] = false
        end
      end
    else
      File.write(TAGGING_LOCK, "#{current_user.id}")
      session[:tagging_lock] = true
    end
    return true
  end

  def calculate_editor_tagging_stats
    @tags_done = Tag.where(approver_id: current_user.id).where.not(status: :pending).count
    @next_tags_milestone = PROGRESS_SERIES.find { |element| element > @tags_done }
    @tags_progress = @tags_done * 100 / @next_tags_milestone
    @taggings_done = Tagging.where(approved_by: current_user.id).where.not(status: :pending).count
    @next_taggings_milestone = PROGRESS_SERIES.find { |element| element > @taggings_done }
    @taggings_progress = @taggings_done * 100 / @next_taggings_milestone
  end

  def redirect_to_next_tagging(t, msg)
    @next_tagging_id = Tagging.where(status: :pending).where('created_at > ?',
                                                             t.created_at).order(:created_at).limit(1).pluck(:id).first
    redirect_to(
      @next_tagging_id.present? ? url_for(tagging_review_path(@next_tagging_id)) : url_for(action: :tag_moderation), notice: msg
    )
  end

  def prepare_similar_tags
    ListItem.where(listkey: 'tag_similarity').pluck(:item_id, :extra).to_h
  end
end
