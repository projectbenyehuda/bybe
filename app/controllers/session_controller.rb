class SessionController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create
  def login
  end

  def do_login
    case params[:commit]
    when 'Google'
      redirect_to '/auth/google_oauth2'
    else
      redirect_to '/', flash: { error: 'No such login method' }
    end
  end

  def create
    User.transaction do
      @user = User.from_omniauth(auth_hash)
      bu = base_user # base_user of anonymous session

      # if user doesn't have a BaseUser (i.e. if this is a new sign up) we link BaseUser from session to newly created user
      if @user.base_user.nil?
        if bu.present? && bu.user.nil?
          bu.update!(session_id: nil, user: @user)
        else
          BaseUser.create!(user: @user)
        end
      else
        # user already has BaseUser record, so we drop BaseUser created for anonymous session if it exists
        if bu.present?
          current_visit.update!(user_id: @user.base_user.id) if current_visit.present? # assign this visit to the authenticated user
          # TODO: consider to move prefs from anonymous BaseUser to user.base_user before deletion
          bu.destroy
        end
      end
    end
    reset_session
    session[:user_id] = @user.id
    redirect_to '/'
  end

  def destroy
    reset_session
    session[:user_id] = nil
    redirect_to '/'
  end

  def dismiss_sitenotice
    session[:dismissed_sitenotice] = true
  end

  protected

  def auth_hash
    request.env['omniauth.auth']
  end
end
