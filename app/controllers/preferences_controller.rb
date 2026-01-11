class PreferencesController < ApplicationController
  def update
    bu = base_user(true)

    # If we couldn't create a base_user (e.g., session couldn't be created),
    # silently fail - user preferences can't be saved without a session
    if bu.nil?
      render json: { status: 'error', message: 'Could not create session' }, status: :unprocessable_content
      return
    end

    pref = params.require(:id)
    value = params.require(:value)
    bu.set_preference(pref, value)
    render json: { head: :ok }
  end
end
