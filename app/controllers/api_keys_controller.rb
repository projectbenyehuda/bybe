# frozen_string_literal: true

require 'csv'

# Public API key signup, plus admin-only management of existing keys
class ApiKeysController < ApplicationController
  before_action :require_admin, except: %i(new create)

  before_action :set_model, only: %i(edit update destroy toggle_status)

  # GET /api_keys
  # GET /api_keys.csv - the full, unpaginated list
  def index
    api_keys = ApiKey.order(:id)
    respond_to do |format|
      format.html { @api_keys = api_keys.page(params[:page]).per(50) }
      format.csv do
        send_data api_keys_csv(api_keys), type: 'text/csv; charset=utf-8', filename: 'api_keys.csv'
      end
    end
  end

  # GET /api_keys/new
  # GET /api_keys/new.json
  def new
    @api_key = ApiKey.new
  end

  # POST /api_keys
  # POST /api_keys.json
  def create
    @api_key = ApiKey.new(key_params)
    @api_key.status = :enabled
    @api_key.key = SecureRandom.hex(32)

    # Extremely simple antispam protection
    unless params['ziburit'] =~ /ביאליק/
      flash.now.alert = 'Antispam protection failed'
      render action: 'new', status: :unprocessable_content
      return
    end

    if @api_key.save
      begin
        ApiKeysMailer.key_created_to_editor(@api_key).deliver
        ApiKeysMailer.key_created(@api_key).deliver
      rescue StandardError => e
        # TODO: add error notification via service like Rollbar
      end

      redirect_to '/', notice: 'Api key was successfully created, check email for details'
    else
      render action: 'new', status: :unprocessable_content
    end
  end

  # PUT /api_keys/1
  # PUT /api_keys/1.json
  def update
    if @api_key.update(key_params)
      redirect_to api_keys_path, notice: 'Api key was successfully updated.'
    else
      render action: 'edit', status: :unprocessable_content
    end
  end

  # DELETE /api_keys/1
  # DELETE /api_keys/1.json
  def destroy
    @api_key.destroy!
    redirect_to api_keys_url
  end

  # PATCH /api_keys/1/toggle_status
  # Disabling a key makes the API reject it (see V1::Validations::AuthKey)
  def toggle_status
    @api_key.update!(status: @api_key.status_enabled? ? :disabled : :enabled)
    redirect_to api_keys_path(page: params[:page]),
                notice: t(@api_key.status_enabled? ? 'api_keys.index.key_enabled' : 'api_keys.index.key_disabled',
                          email: @api_key.email)
  end

  private

  def api_keys_csv(api_keys)
    "\uFEFF" + CSV.generate do |csv|
      csv << %w(id email description key status created_at calls_count last_used_at)
      api_keys.find_each do |k|
        csv << [k.id, k.email, k.description, k.key, k.status, k.created_at.iso8601, k.calls_count,
                k.last_used_at&.iso8601]
      end
    end
  end

  def key_params
    params[:api_key].permit(:id, :description, :email, :status)
  end

  def set_model
    @api_key = ApiKey.find(params[:id])
  end
end
