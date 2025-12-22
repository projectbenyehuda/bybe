# handle everything related to Tags and Taggings
class TaggingsController < ApplicationController
  before_action :require_user, except: %i(browse tag_portal tag_by_name) # for now, we don't allow anonymous taggings
  before_action :require_editor, only: [:rename_tag]
  layout false, only: %i(render_tags suggest add_tagging_popup listall_tags pending_taggings_popup)

  def add_tagging_popup
    @taggable = instantiate_taggable(params[:taggable_type], params[:taggable_id])
    if @taggable.instance_of?(Manifestation)
      @author = @taggable.authors.first
    elsif @taggable.instance_of?(Authority)
      @author = @taggable
    end
    @tagging = Tagging.new
    @tagging.suggester = current_user
    @tagging.status = :pending
    @tagging.taggable = @taggable
    @recent_tags_by_user = current_user.recent_tags_used
  end

  def pending_taggings_popup
    @tag = Tag.find(params[:tag_id])
    @taggings = @tag.taggings.pending
  end

  def create # creates a tagging and, if necessary, a tag
    if params[:tag].present?
      if params[:tag_id].present? # selecting from autocomplete would populate this
        tag = Tag.find(params[:tag_id])
      else # user may have typed an existing tag name or alias without selecting from autocomplete
        tname = TagName.find_by_name(params[:tag])
        tag = tname.nil? ? nil : tname.tag
      end
      if tag.nil? # user submitted a nonexistent tag name
        tag = Tag.create!(name: params[:tag], creator: current_user, status: :pending)
        TagSimilarityJob.perform_async(tag.id) # schedule a job to find similar tags
      end
      # TODO: handle case where tag exists but has already been rejected, and DO NOT create a tagging
    elsif params[:suggested_tag_id].present?
      tag = Tag.find(params[:suggested_tag_id])
    else
      head :not_found
    end
    return unless tag

    @t = Tagging.new(taggable: instantiate_taggable(params[:taggable_type], params[:taggable_id]),
                     suggester: current_user, status: :pending)
    tag.taggings << @t
  end

  def destroy
    # TODO: implement
    tagging = Tagging.find(params[:id])
    return if tagging.nil?
    unless tagging.pending? && (tagging.suggested_by == current_user.id || (current_user.editor? && current_user.has_bit?('moderate_tags')))
      return
    end

    @taggable_id = tagging.taggable_id
    @taggable_type = tagging.taggable_type
    tagging.destroy
  end

  def browse # public tags listing
    @page_title = "#{t(:tags_list)} – #{t(:project_ben_yehuda)}"
    @sort = params[:sort_by] || 'alphabetical'
    @show_all = params[:show_all] == 'true'

    tags_query = Tag.approved
    tags_query = case @sort
                 when 'popularity'
                   tags_query.order(approved_taggings_count: :desc, name: :asc)
                 else # 'alphabetical'
                   tags_query.order(name: :asc)
                 end

    @total = tags_query.count
    @tags = @show_all ? tags_query : tags_query.page(params[:page])
  end

  def list_tags # for backend
    # TODO: handle filters
    @page = params[:page]
    @page = 1 unless @page.present?
    @tags = Tag.approved.all.page(@page)
    render 'list_tags', layout: true
  end

  def listall_tags # for frontend
    order = params[:order] == 'abc' ? 'name asc' : 'taggings_count desc'
    @tags = Tag.approved.all.order(order) # TODO: at some point, we'll need to paginate this
    # @tags = Tagging.approved.joins(:tag).order(:name).pluck(:tag_id,:name).group_by(&:pop).map{|x| {id: x[1][0], name: x[0], count: x[1].length}} # TODO: at some point, we'll need to paginate this
  end

  def render_tags
    @taggable = instantiate_taggable(params[:taggable_type], params[:taggable_id])
    @taggings = @taggable.nil? ? [] : @taggable.taggings
  end

  def suggest
    @tag_suggestions = {}
    if params[:author].present?
      @tag_suggestions[:used_on_other_works] = Authority.find(params[:author]).cached_popular_tags_used_on_works
    end
    if current_user.present?
      @tag_suggestions[:popular_tags_by_user] = current_user.cached_popular_tags_used
      @tag_suggestions[:recent_tags_by_user] = current_user.recent_tags_used
    end
    @tag_suggestions[:popular_tags] = Tag.cached_popular_tags
  end

  def tag_by_name
    @tag = Tag.by_name(params[:name]).first
    if @tag.present?
      redirect_to tag_path(@tag.id)
    else
      flash[:error] = t(:tag_not_found)
      redirect_to root_path
    end
  end

  def tag_portal
    @tag = Tag.find(params[:id])
    if @tag.present? && @tag.approved?
      @taggings = @tag.taggings.approved
      @page_title = "#{@tag.name} - #{t(:tag_page)}"
      # debugger
      @tagged_authors_count = Authority.tagged_with(@tag.id).count
      @tagged_authors = Authority.tagged_with(@tag.id).order(impressions_count: :desc).limit(10)
      @tagged_works_count = Manifestation.tagged_with(@tag.id).count
      @popular_tagged_works = Manifestation.tagged_with(@tag.id).order(impressions_count: :desc).limit(10)
      @newest_tagged_works = Manifestation.tagged_with(@tag.id).order('created_at desc').limit(10)
    else
      flash[:error] = t(:tag_not_found)
      redirect_to root_path
    end
  end

  # editor actions
  def rename_tag
    @tag = Tag.find(params[:id])
    newname = params[:name]
    existingtag = Tag.by_name(newname)
    if existingtag.empty?
      @tag.name = newname
      @tag.save!
      flash[:notice] = t(:tag_renamed, newname: newname)
    else
      @tag.merge_taggings_into(existingtag.first)
      @tag.destroy
      flash[:notice] = t(:taggings_merged, toname: existingtag.first.name)
    end
    # TODO: render or redirect
  end

  protected

  def instantiate_taggable(klass, id)
    case klass
    when 'Manifestation'
      Manifestation.find(id)
    when 'Authority'
      Authority.find(id)
    when 'Anthology'
      Anthology.find(id)
    when 'Work'
      Work.find(id)
    when 'Expression'
      Expression.find(id)
    when 'Collection'
      Collection.find(id)
    else
      raise "Unsupported taggable type: #{klass}"
    end
  end
end
