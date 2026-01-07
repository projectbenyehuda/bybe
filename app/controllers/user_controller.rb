class UserController < ApplicationController
  before_action :require_admin, only: [:list, :make_crowdsourcer, :unmake_crowdsourcer, :make_editor, :make_admin, :unmake_editor, :set_editor_bit]
  before_action :require_user

  def list
    @user_list = User.all

    # Apply text search filter
    if params[:q].present?
      @user_list = @user_list.where("name like '%#{sanitize(params[:q])}%' OR email like '%#{sanitize(params[:q])}%'")
      @q = params[:q]
    end

    # Apply privilege filter
    @privilege_filter = params[:privilege_filter]
    case @privilege_filter
    when 'editor'
      @user_list = @user_list.where(editor: true)
    when 'admin'
      @user_list = @user_list.where(admin: true)
    when 'crowdsourcer'
      @user_list = @user_list.where(crowdsourcer: true)
    when 'editor_or_admin'
      @user_list = @user_list.where('editor = 1 OR admin = 1')
    end

    @user_list = @user_list.page params[:page]
  end
  def make_crowdsourcer
    set_user
    @u.crowdsourcer = true
    @u.save!
    redirect_to url_for(list_params), notice: "#{@u.name} is now a crowdsourcer."
  end

  def make_editor
    set_user
    @u.editor = true
    @u.save!
    redirect_to url_for(list_params), notice: "#{@u.name} is now an editor."
  end

  def make_admin
    set_user
    @u.admin = true
    @u.save!
    redirect_to url_for(list_params), notice: "#{@u.name} is now an admin."
  end

  def unmake_editor
    set_user
    @u.editor = false
    @u.save!
    redirect_to url_for(list_params), notice: "#{@u.name} is no longer an editor."
  end

  def unmake_crowdsourcer
    set_user
    @u.crowdsourcer = false
    @u.save!
    redirect_to url_for(list_params), notice: "#{@u.name} is no longer a crowdsourcer."
  end

  def show
  end

  def set_editor_bit
    set_user
    if @u.editor? and params[:bit] and (params[:bit].empty? == false) and params[:set_to] and (params[:set_to].empty? == false)
      if params[:set_to].to_i == 1
        action = t(:added_to_group)
        li = ListItem.where(listkey: params[:bit], item: @u).first
        unless li
          li = ListItem.new(listkey: params[:bit], item: @u)
          li.save!
        end
      else # zero == remove from list having the bit
        action = t(:removed_from_group)
        li = ListItem.where(listkey: params[:bit], item: @u).first
        li.destroy if li
      end
    end
    redirect_to url_for(list_params), notice: "#{@u.name} #{action} #{t(params[:bit])}"
  end

  protected

  def set_user
    @u = User.find(params[:id])
    if @u.nil?
      redirect_to url_for(controller: :admin, action: :index), flash: {error: t(:no_such_user)}
    end
  end

  def list_params
    {
      action: :list,
      q: params[:q],
      page: params[:page],
      privilege_filter: params[:privilege_filter]
    }
  end
end
