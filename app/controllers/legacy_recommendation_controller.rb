class LegacyRecommendationController < ApplicationController

  protect_from_forgery :except => :submit # allow submission from outside the app
  before_action :require_editor, :only => [:index, :list, :show, :resolve, :purge]

  def create
    unless params['what'].nil? or params['what'].empty? # don't bother capturing null submissions
      @p = Recommendation.new(
        from: params['email'],
        about: params['about'] || request.env['HTTP_REFERER'] || 'none',
        what: params['what'],
        subscribe: (params['subscribe'] == 'yes'),
        status: 'new'
      )
      h = HtmlFile.find_by(url: @p.about.sub(%r{https?://.*benyehuda.org/}, ''))
      @p.html_file = h unless h.nil?
      @p.save!
    end
  end
  def index
    redirect_to :action => :list
  end
  def list
    # calculate tallies
    @count = { :all => LegacyRecommendation.count, :open => LegacyRecommendation.where(status: 'new').count, :accepted => LegacyRecommendation.where(status: 'accepted').count, :rejected => LegacyRecommendation.where(status: 'rejected').count }
    if params[:status].nil?
      @recs = LegacyRecommendation.page(params[:page]).order(:about)
    else
      @recs = LegacyRecommendation.where(status: params[:status]).page(params[:page]).order(:about)
    end
  end

  def show
    @p = LegacyRecommendation.find(params[:id])
    @p.what = '' if @p.what.nil?
  end

  def resolve
    @p = LegacyRecommendation.find(params[:id])
    error = nil
    if @p.nil?
      error = t(:no_such_item)
    else
      if params[:accept] == 'yes'
        @p.status = 'accepted'
        unless @p.from.nil? or @p.from !~ /\w+@\w+\.\w+/
          Notifications.recommendation_accepted(@p, @p.about).deliver
        end
        text = 'ההמלצה התקבלה וממתינה לשילוב ביומן הרשת'
      elsif params[:accept] == 'no'
        @p.status = 'rejected'
        text = 'ההמלצה נדחתה ותימחק עם השאר'
      elsif params[:accept] == 'archive'
        @p.status = 'archived'
        text = 'ההמלצה אורכבה בלי לשלוח דואל'
      elsif params[:accept] == 'blogged'
        if params[:url].nil? or params[:url].empty?
          error = t(:no_url_specified)
        else
          @p.status = 'archived'
          unless @p.from.nil? or @p.from !~ /\w+@\w+\.\w+/
            Notifications.recommendation_published(@p, @p.about, params[:url]).deliver # send "blogged" notice
          end
          text = 'ההמלצה אורכבה ונשלח דואל לממליץ/ה'
        end
      end
    end
    if error.nil?
      @p.resolved_by = session[:user]
      @p.save!
      flash[:notice] = t(:resolved_as, :fixed => text)
    else
      flash[:error] = error
    end
    redirect_to :action => :list
  end
  def purge
    LegacyRecommendation.where(status: 'rejected').delete_all
    flash[:notice] = t(:purged)
    redirect_to :action => :list
  end
end
