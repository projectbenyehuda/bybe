# frozen_string_literal: true

# Controller for user email preferences
class UserPreferencesController < ApplicationController
  before_action :require_user

  def edit
    @base_user = current_user_base_user
    @email_frequency = @base_user.get_preference(:email_frequency) || 'unlimited'
  end

  def update
    @base_user = current_user_base_user
    email_frequency = params[:email_frequency]

    if BaseUser::EMAIL_FREQUENCY_OPTIONS.include?(email_frequency)
      @base_user.set_preference(:email_frequency, email_frequency)
      flash[:notice] = t(:preferences_updated)
      redirect_to edit_user_preferences_path
    else
      flash[:error] = t(:invalid_preference)
      @email_frequency = email_frequency
      render :edit
    end
  end

  private

  def current_user_base_user
    # Find or create BaseUser for current user
    current_user.base_user || BaseUser.create!(user: current_user)
  end
end
