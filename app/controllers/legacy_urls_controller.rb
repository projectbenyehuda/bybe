# frozen_string_literal: true

# CRUD interface for managing LegacyUrl records (editor-only).
class LegacyUrlsController < ApplicationController
  before_action :require_editor
  before_action :set_legacy_url, only: %i(show edit update destroy)

  def index
    @legacy_urls = LegacyUrl.ordered.page(params[:page])
  end

  def show; end

  def new
    @legacy_url = LegacyUrl.new
  end

  def edit; end

  def create
    @legacy_url = LegacyUrl.new(legacy_url_params)
    if @legacy_url.save
      redirect_to legacy_urls_path, notice: t('legacy_urls.created')
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @legacy_url.update(legacy_url_params)
      redirect_to legacy_urls_path, notice: t('legacy_urls.updated')
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @legacy_url.destroy
    redirect_to legacy_urls_path, notice: t('legacy_urls.destroyed')
  end

  private

  def set_legacy_url
    @legacy_url = LegacyUrl.find(params[:id])
  end

  def legacy_url_params
    params.expect(legacy_url: %i(from_url target_type target_id description))
  end
end
