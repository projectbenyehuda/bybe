class ApplicationController < ActionController::Base
  protect_from_forgery
  before_action :set_paper_trail_whodunnit
  # before_action :set_font_size # TODO: re-enable when we support this
  before_action :set_base_user
  before_action :mention_skipped
  after_action :set_access_control_headers
  autocomplete :tag_name, :name, limit: 15, scopes: [:approved], extra_data: [:tag_id] # TODO: also search alternate titles!

  # returns BaseUser record associated with current user
  # If user is authenticated it will look for record by user_id, otherwise - by session_id
  # If force_create arg is set to true it will create new BaseUser record for user if it doesn't exists
  def base_user(force_create = false)
    return @base_user if @base_user.present?

    if session.id.nil?
      return nil unless force_create

      # if no session exists we need to write something there to create anonymous session
      session[:dummy] = true
      session.delete(:dummy)

      # no session exists, so no stored data for this user yet

    end

    attrs = if current_user
              # Authenticated user
              { user: current_user }
            else
              # Not authenticated user
              # We use 'private_id' to have same format as used in Sessions table
              { session_id: session.id.private_id }
            end

    @base_user = BaseUser.find_by(attrs)
    if @base_user.nil? && force_create
      @base_user = BaseUser.create!(attrs)
    end

    return @base_user
  end

  def set_font_size
    @fontsize = if base_user
                  base_user.get_preference(:fontsize)
                else
                  BaseUser::DEFAULT_FONT_SIZE
                end
  end

  def set_access_control_headers
    #    headers['Access-Control-Allow-Origin'] = 'http://benyehuda.org/'
    headers['Access-Control-Allow-Origin'] = '*' # TODO: restrict
    headers['Access-Control-Allow-Methods'] = '*'
    headers['Access-Control-Request-Method'] = '*'
    headers['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept'
  end

  def mobile_search
    render partial: 'shared/mobile_search'
  end

  protected

  def require_editor(bits = nil)
    editor = current_user && current_user.editor?
    if editor
      return true if bits.nil?

      # else check for specific bits
      li = ListItem.where(listkey: bits, item: current_user).first
      return true unless li.nil?
    end

    redirect_to '/', flash: { error: I18n.t(:not_an_editor) }
  end

  def set_base_user
    @bu = base_user
  end

  def require_admin
    u = current_user || (session.present? && session[:user_id].present? ? User.find(session[:user_id]) : nil) # in case current_user is not set
    return true if u && u.admin?

    redirect_to '/', flash: { error: I18n.t(:not_an_admin) }
  end

  def require_user
    return true if current_user

    redirect_to session_login_path, flash: {
      error: I18n.t(:must_be_logged_in)
    }
  end

  def require_crowdsourcer
    return true if current_user && current_user.crowdsourcer?

    redirect_to '/', flash: { error: I18n.t(:not_a_crowdsourcer) }
  end

  def cached_popular_tags
    Rails.cache.fetch('popular_tags', expires_in: 24.hours) do # memoize
      Tagging.group(:tag).order('count_tag_id DESC').count('tag_id')
    end
  end

  def cached_newest_authors
    Rails.cache.fetch('newest_authors', expires_in: 6.hours) do # memoize
      Person.published.has_toc.has_image.left_joins(%i(expressions
                                                       works)).group('people.id').having('COUNT(works.id) > 0 OR COUNT(expressions.id) > 0').order(published_at: :desc).limit(10)
    end
  end

  def popular_authors(update = false)
    Authority.recalc_popular if update
    @popular_authors = Authority.popular_authors
  end

  def randomize_authors(exclude_list, genre = nil)
    list = []
    ceiling = [Person.cached_toc_count - exclude_list.count - 1, 10].min
    return list if ceiling <= 0

    i = 0
    begin
      if genre.nil?
        candidates = Person.has_toc.order('RAND()').limit(ceiling - list.size) # fetch as many as are still needed
      else
        candidates = Person.has_toc.joins(:expressions).where(expressions: { genre: genre }).order('RAND()').limit(ceiling - list.size) # fetch as many as are still needed
      end

      candidates.each { |author| list << author unless (exclude_list.include? author) or (list.include? author) }
      i += 1
    end until list.size >= ceiling or i > 10 # TODO: fix bug where only one author is retrieved by above block
    return list
  end

  def randomize_works_by_genre(genre, how_many)
    return Manifestation.where(id: Manifestation.published.joins(expression: :work).where({ works: { genre: genre } }).pluck(:id).sample(how_many))
  end

  def randomize_works(how_many)
    return Manifestation.where(id: Manifestation.published.pluck(:id).sample(how_many)) # ORDER RAND() is way too slow!
  end

  def cached_authors_in_genre
    Rails.cache.fetch('au_by_genre', expires_in: 24.hours) do # memoize
      totals = Work.joins(involved_authorities: :authority)
                   .merge(InvolvedAuthority.role_author)
                   .group(:genre)
                   .distinct
                   .count('authorities.id')
                   .to_h
      get_genres.index_with { |genre| totals[genre] || 0 }
    end
  end

  def cached_authors_in_period
    Rails.cache.fetch('au_by_period', expires_in: 24.hours) do # memoize
      ret = {}
      get_periods.each do |p|
        ret[p] = Work.joins(:expressions, involved_authorities: :authority)
                     .merge(InvolvedAuthority.role_author)
                     .where(expressions: { period: p })
                     .distinct
                     .count('authorities.id')
      end
      ret
    end
  end

  def cached_works_by_period
    Rails.cache.fetch('works_by_period', expires_in: 24.hours) do # memoize
      totals = Manifestation.published.joins(:expression).group(:period).count
      get_periods.index_with { |period| totals[Expression.periods[period]] || 0 }
    end
  end

  def prep_edit_toc
    @toc = @toc.toc
    @credit_section = @author.toc.credit_section.nil? ? '' : @author.toc.credit_section
    @toc_timestamp = @author.toc.updated_at
    @works = @author.all_works_including_unpublished
    @works_options = @works.map do |m|
                       [@toc.index('מ' + m.id.to_s) ? "#{t(:already_in_toc)} #{m.title}" : m.title, m.id]
                     end.sort_by { |opt| opt[0] }
    @fresh_works = # in the fresh_works context, the order of creation is more useful, and created_at creates a jumble because its granularity is too coarse
      @works.select do |m|
        @toc.index('מ' + m.id.to_s).nil?
      end.sort_by { |m| m.id }
    # @fresh_works = @author.works_since(12.hours.ago, 1000)
    unless @fresh_works.empty?
      @fresh_works_markdown = @fresh_works.map do |m|
        "\\n&&& פריט: מ#{m.id} &&& כותרת: #{m.title}#{' / ' + m.authors_string if m.expression.translation} &&&\\n"
      end.join('').html_safe
    else
      @fresh_works_markdown = ''
    end
  end

  def prep_toc
    return unless @author.toc.present? || @author.legacy_toc_id.present?

    @toc = @author.toc || Toc.find(@author.legacy_toc_id)
    unless @toc.cached_toc.present?
      @toc.update_cached_toc
      @toc.save
    end
    markdown_toc = @toc.cached_toc
    toc_parts = divide_by_genre(markdown_toc)
    @genres_present = toc_parts.shift # first element is the genres array
    @htmls = toc_parts.map { |genre, tocpart| [genre, MultiMarkdown.new(tocpart).to_html.force_encoding('UTF-8')] }
    credits = @toc.credit_section || ''
    unless credits =~ /by-horizontal/
      credits.sub!('## הגיהו',
                   "<div class=\"by-horizontal-seperator-light\"></div>\n\n## הגיהו")
    end
    @credits = MultiMarkdown.new(credits).to_html.force_encoding('UTF-8')
  end

  # prepare the overall collection-based TOC management view for a given Authority
  def prep_manage_toc
    @publications = @author.publications.no_volume.order(:title)
    @pub_options = []
    pub_details = []
    @publications.each do |pub|
      @pub_options << [pub.title, pub.id]
      pub_details << { id: pub.id, title: pub.title, year: pub.pub_year, publisher: pub.publisher_line }
    end
    @pub_details = pub_details.to_json
    @already_collected_ids = @author.collected_manifestation_ids
    # refresh uncollected works to reflect any changes we may have just made
    RefreshUncollectedWorksCollection.call(@author)
  end

  def generate_toc
    ## legacy code below
    # @works = @author.cached_original_works_by_genre
    # @translations = @author.cached_translations_by_genre
    # @genres_present = []
    # @works.each_key { |k| @genres_present << k unless @works[k].size == 0 || @genres_present.include?(k) }
    # @translations.each_key { |k| @genres_present << k unless @works[k].size == 0 || @genres_present.include?(k) }
  end

  def whatsnew_anonymous
    Rails.cache.fetch('whatsnew_anonymous', expires_in: 2.hours) do # memoize
      logger.info('cache miss: calculating whatsnew anonymous')
      whatsnew_since(1.month.ago)
    end
  end

  def cached_newsfeed
    Rails.cache.fetch('cached_newsfeed', expires_in: 1.hour) do # memoize
      newsfeed
    end
  end

  def cached_youtube_videos
    Rails.cache.fetch('cached_youtube', expires_in: 24.hours) do # memoize
      # return latest_youtube_videos # commented out due to quote problem, and caching failure yet TBD
      []
    end
  end

  def latest_youtube_videos
    ret = []
    begin
      channel = Yt::Channel.new id: Rails.configuration.constants['youtube_channel_id']
      vids = channel.videos
      max = vids.count > 5 ? 5 : vids.count
      i = 0
      vids.each  do |v|
        break if i >= max

        ret << [v.title, v.description, v.id, v.thumbnail_url, v.published_at]
        i += 1
      end
    rescue StandardError
      puts 'No network?'
    end
    return ret
  end

  def youtube_url_from_id(id)
    return 'https://www.youtube.com/watch?v=' + id
  end

  public # temp

  def newsfeed
    unsorted_news_items = NewsItem.last(5) # read at most the last 5 persistent news items (Facebook posts, announcements)

    whatsnew_since(1.month.ago).each do |person, pubs| # add newly-published works
      unsorted_news_items << NewsItem.from_publications(
        person,
        textify_new_pubs(pubs),
        pubs,
        authority_path(person.id),
        person.profile_image.url(:thumb)
      )
    end
    cached_youtube_videos.each do |title, desc, id, thumbnail_url, relevance| # add latest videos
      unsorted_news_items << NewsItem.from_youtube(title, desc, youtube_url_from_id(id), thumbnail_url, relevance)
    end
    # TODO: add latest blog posts
    return unsorted_news_items.sort_by { |item| item.relevance }.reverse # sort by descending relevance
  end

  def whatsnew_since(timestamp)
    authors = {}
    Manifestation.all_published.new_since(timestamp).includes(:expression).each do |m|
      e = m.expression
      next if e.nil? # shouldn't happen

      w = e.work
      authority = e.translation ? m.translators.first : m.authors.first # TODO: more nuance
      next if authority.nil? # shouldn't happen, but might in a dev. env.

      if authors[authority].nil?
        authors[authority] = {}
        authors[authority][:latest] = 0
      end
      authors[authority][w.genre] = [] if authors[authority][w.genre].nil?
      authors[authority][w.genre] << m
      authors[authority][:latest] = m.updated_at if m.updated_at > authors[authority][:latest]
    end
    authors
  end

  def textify_new_pubs(author)
    ret = ''
    author.each do |genre|
      next unless genre[1].class == Array # skip the :latest key

      worksbuf = "<strong>#{helpers.textify_genre(genre[0])}:</strong> "
      first = true
      genre[1].each do |m|
        title = m.expression.title
        if m.expression.translation
          per = m.expression.work.authors[0] # TODO: add handing for several persons
          unless per.nil?
            title += " #{I18n.t(:by)} #{per.name}"
          end
        end
        if first
          first = false
        else
          worksbuf += '; '
        end
        worksbuf += "<a href=\"/read/#{m.id}\">#{title}</a>"
      end
      ret += worksbuf + '<br />'
    end
    return ret
  end

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  rescue ActiveRecord::RecordNotFound
    # Should only happen in development environment
    session.delete(:user_id)
  end

  def html_entities_coder
    @html_entities_coder ||= HTMLEntities.new
  end

  def set_tab(tab)
    tabs = %w(contact help faq authors works periods)
    ret = {}
    tabs.each { |t| ret[t] = tab == t ? 'active' : '' }
    return ret
  end

  def generate_new_anth_name_from_set(anths)
    i = 1
    prefix = I18n.t(:anthology)
    new_anth_name = prefix + "-#{i}"
    anth_titles = @anthologies.pluck(:title)
    loop do
      new_anth_name = prefix + "-#{i}"
      i += 1
      break unless anth_titles.include?(new_anth_name)
    end
    return new_anth_name
  end

  def prep_user_content(context = :manifestation)
    if context == :manifestation
      if base_user.present?
        @bookmark = base_user.bookmarks.where(manifestation: @m).first&.bookmark_p || 0
        @jump_to_bookmarks = base_user.get_preference(:jump_to_bookmarks)
      else
        @bookmark = 0
      end
    end

    return unless current_user

    @anthologies = current_user.anthologies
    @new_anth_name = generate_new_anth_name_from_set(@anthologies)
    if session[:current_anthology_id].nil?
      unless @anthologies.empty?
        @anthology = @anthologies.first
        session[:current_anthology_id] = @anthology.id
      end
    else
      begin
        @anthology = Anthology.find(session[:current_anthology_id])
      rescue StandardError
        session[:current_anthology_id] = nil # if somehow deleted without resetting the session variable (e.g. during development)
        @anthology = @anthologies.first
      end
    end
    @anthology_select_options = @anthologies.map { |a| [a.title, a.id, @anthology == a ? 'selected' : ''] }
    @cur_anth_id = @anthology.nil? ? 0 : @anthology.id
  end

  def prep_toc_as_collection
    @top_nodes = GenerateTocTree.call(@author)
  end

  def mention_skipped
    return unless params[:skipped].present?

    flash.now[:notice] = I18n.t(:skipped_x_items, x: params[:skipped]) # the .now avoid showing the flash on the next page
  end

  helper_method :current_user, :html_entities_coder
end
