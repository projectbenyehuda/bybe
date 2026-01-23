include BybeUtils

class BibController < ApplicationController
  layout 'backend'
  before_action { |c| c.require_editor('bib_workshop') }
  def index
    @counts = {
      pubs: Publication.count,
      holdings: Holding.count,
      obtained: Publication.obtained.count,
      scanned: Publication.scanned.count,
      copyrighted: Publication.copyrighted.count,
      uploaded: Publication.uploaded.count,
      irrelevant: Publication.irrelevant.count,
      missing: Holding.missing.count,
      authors_done: Authority.has_toc.bib_done.count,
      authors_todo: Authority.has_toc.count - Authority.has_toc.bib_done.count
    }

    @digipubs = Publication.scanned.includes(holdings: :bib_source).order('rand()').limit(25)
    pid = params[:authority_id]
    if pid.present?
      @authority_id = pid.to_i
      @authority_name = Authority.find(@authority_id).name.split[-1]
    end
    prepare_pubs
  end

  def publication_mark_false_positive
    pub = Publication.find(params[:id])
    li = ListItem.new(listkey: 'pubs_false_maybe_done', item: pub)
    li.save!
    li = ListItem.where(listkey: 'pubs_maybe_done', item: pub)
    unless li.empty?
      li.each { |item| item.destroy }
    end
    render js: "$('.pub#{pub.id}').remove();"
  end

  def scans
    @digipubs = Publication.includes(holdings: :bib_source).where(status: Publication.statuses[:scanned]).order('updated_at asc')
  end

  def make_author_page
    @authority = Authority.find(params[:authority_id])
    @pubs = @authority.publications
    gen_toc = ''
    # make TOC
    @pubs.each do |pub|
      gen_toc += "### #{pub.title}\n#{pub.publisher_line}, #{pub.pub_year} \n\n"
    end
    gen_toc = gen_toc.gsub(' :', ':').gsub(' ;', ';')
    # save TOC to person if no TOC yet
    if @authority.toc.nil?
      t = Toc.create!(
        toc: gen_toc,
        credit_section: "## #{I18n.t(:typed)}\n* ...\n\n## #{I18n.t(:proofed)}\n* ...",
        status: :raw
      )
      @authority.toc = t
      @authority.save!
    else
      @gen_toc = gen_toc # set @gen_toc for edit_toc to show
    end
    # present TOC if person already has manual TOC
    flash.now.notice = t(:created_toc)
    @author = @authority
    prep_toc
    prep_edit_toc

    render 'authors/edit_toc'
  end

  def authority
    @authority = Authority.find(params[:authority_id])
    @pubs = @authority.publications.order(:status)
    respond_to do |format|
      format.html
      format.js
    end
  end

  def pubs_by_authority
    prepare_pubs
    q = params['q']
    @authority_id = params[:authority_id]
    if @authority_id.present?
      @authority = Authority.find(@authority_id)
    end
    @total_pubs = '0'
    return if q.nil? or q.empty?

    @pubs = []

    sources = []
    if params['bib_source'] == 'all'
      sources = BibSource.enabled
    else
      sources << BibSource.find(params['bib_source'])
    end
    sources.each do |bib_source|
      @pubs += query_source_by_type(q, bib_source).select do |pub|
        Holding.where(source_id: url_for_record(bib_source,
                                                (pub.source_id.class == Array ? pub.source_id[0] : pub.source_id))).empty?
      end
    end
    @total_pubs = @pubs.count.to_s
  end

  def make_scanning_task
    pub = Publication.find(params[:id])
    if pub.nil?
      render plain: 'moose'
    else
      Net::HTTP.start(Rails.configuration.constants['tasks_system_host'],
                      Rails.configuration.constants['tasks_system_port'], use_ssl: Rails.configuration.constants['tasks_system_port'] == 443) do |http|
        req = Net::HTTP::Post.new('/api/create_task')
        req.set_form_data(title: pub.title, author: pub.author_line,
                          edition_details: "#{pub.publisher_line}, #{pub.pub_year}", extra_info: "#{pub.language}\n#{pub.notes}",
                          api_key: current_user.tasks_api_key)
        task_result = JSON.parse(http.request(req).body)
        logger.debug("task_result: #{task_result}")
        if task_result['task'].present?
          pub.status = 'scanned'
          pub.task_id = task_result['task']['id']
          pub.save!
          portpart = Rails.configuration.constants['tasks_system_port'] == 80 ? '' : ":#{Rails.configuration.constants['tasks_system_port']}"
          taskurl = "#{Rails.configuration.constants['tasks_system_port'] == 443 ? 'https://' : 'http://'}#{Rails.configuration.constants['tasks_system_host']}#{portpart}/tasks/#{task_result['task']['id']}"
          render inline: taskurl
        else
          render inline: 'alert("אירעה שגיאה ביצירת המשימה.");'
        end
      end
    end
  end

  def todo_by_location
    loc = params['location']
    Holding.where(status: Holding.statuses[:todo])
  end

  def pubs_maybe_done
    @pubs = []
    ListItem.includes(:item).where(listkey: 'pubs_maybe_done').each do |pub|
      item = pub.item
      mm = item.authority.all_works_by_title(pub_title_for_comparison(item.title))
      @pubs << [item, mm]
    end
  end

  def shopping
    hh = []
    if params[:pd] == '1' && params[:unique] == '1'
      # get all publications available in only one source
      pp = Publication.joins(:holdings, :authority)
                      .group('publications.id')
                      .having('COUNT(distinct holdings.bib_source_id) = 1')
                      .merge(Authority.intellectual_property_public_domain)
                      .where("publications.status = 'todo' and holdings.bib_source_id = ?", params[:source_id])
      pp.each { |p| p.holdings.each { |h| hh << h } }
    elsif params[:pd] == '1' && (params[:unique].nil? || params[:unique] == '0')
      hh = Holding.to_obtain(params[:source_id])
                  .joins(publication: :authority)
                  .includes(publication: :holdings)
                  .merge(Authority.intellectual_property_public_domain)
                  .where("publications.status = 'todo'").to_a
    elsif (params[:pd].nil? || params[:pd] == '0') && params[:unique] == '1'
      # get all publications available in only one source
      pp = Publication.joins(:holdings).group('publications.id')
                      .having('COUNT(distinct holdings.bib_source_id) = 1')
                      .where('publications.status = "todo"')
      pp.each { |p| p.holdings.each { |h| hh << h if h.bib_source_id == params[:source_id].to_i } }
    elsif params[:nonpd] == '1' && params[:unique] == '1'
      # get all publications available in only one source
      pp = Publication.joins(:holdings, :authority)
                      .group('publications.id')
                      .having('COUNT(distinct holdings.bib_source_id) = 1')
                      .where('publications.status = "todo"')
                      .where.not(
                        'authorities.intellectual_property = ?',
                        Authority.intellectual_properties[:public_domain]
                      )
      pp.each { |p| p.holdings.each { |h| hh << h if h.bib_source_id == params[:source_id].to_i } }
    elsif params[:nonpd] == '1' && (params[:unique].nil? || params[:unique] == '0')
      hh = Holding.to_obtain(params[:source_id])
                  .joins(publication: :authority)
                  .includes(publication: :holdings)
                  .where.not(
                    'authorities.intellectual_property = ?',
                    Authority.intellectual_properties[:public_domain]
                  ).to_a
    else
      hh = Holding.to_obtain(params[:source_id]).to_a
    end

    # Sort holdings by location
    sorted_holdings = hh.sort_by! do |h|
      loc = h.location || ''
      s = loc.sub(/\(.*\)/, '').tr('[א-ת]', '')
      pos = s.index('.') || -1
      s[0..pos]
    end

    # De-duplicate by publication (keep first holding for each publication)
    unique_holdings = sorted_holdings.uniq(&:publication_id)

    # Paginate (50 items per page)
    @holdings = Kaminari.paginate_array(unique_holdings)
                        .page(params[:page])
                        .per(50)

    @source = BibSource.find(params[:source_id])
  end

  def holding_status
    @holding = Holding.find(params[:id])
    pub = @holding.publication
    @holding.status = params[:status]
    @holding.save!
    if pub.status == 'todo' and %w(scanned obtained).include?(params[:status])
      pub.status = params[:status]
      pub.save!
    end
    @the_id = case params[:status]
              when 'obtained'
                "obt#{@holding.id}"
              when 'scanned'
                "scn#{@holding.id}"
              when 'missing'
                "msng#{@holding.id}"
              end
  end

  private

  def prepare_pubs
    @select_options = BibSource.enabled.map { |tn| [tn.title, tn.id] }.unshift([I18n.t(:all_sources), :all])
  end

  def query_source_by_type(q, bib_source)
    case bib_source.source_type
    when 'aleph'
      provider = Gared::Aleph.new(bib_source.url, bib_source.port, bib_source.institution)
    when 'googlebooks'
      provider = Gared::Googlebooks.new(bib_source.api_key)
    when 'hebrewbooks'
      provider = Gared::Hebrewbooks.new
    when 'primo'
      provider = Gared::Primo.new(bib_source.url, bib_source.vid, bib_source.scope, bib_source.api_key)
    when 'idea'
      provider = Gared::Idea.new(bib_source.url)
    when 'nli_api'
      provider = Gared::Nli_Api.new(bib_source.url, bib_source.api_key)
    end
    ret = []
    # debugger
    ret = provider.query_publications_by_person(q, bib_source) if provider # bib_source is sent as context, so that the resulting Publication objects would be able to access the linkify logic for their source; should probably be replaced by a proc
    return ret
  end
end
