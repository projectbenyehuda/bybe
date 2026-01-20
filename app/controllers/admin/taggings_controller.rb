# frozen_string_literal: true

# Admin controller for managing Taggings
module Admin
  # Taggings controller handles viewing and deleting Taggings
  class TaggingsController < ApplicationController
    before_action :require_editor, only: %i(index show destroy)
    before_action :check_moderate_tags_permission
    before_action :set_tagging, only: %i(show destroy)

    layout 'backend'

    def index
      @taggings = Tagging.includes(:tag, :suggester, :taggable).order(created_at: :desc)

      # Filter by tagged item title (search across polymorphic associations)
      if params[:item_q].present?
        search_term = "%#{params[:item_q]}%"
        # For polymorphic associations, we need to search separately by type
        manifestation_ids = Manifestation.where('title LIKE ?', search_term).pluck(:id)
        authority_ids = Authority.where('name LIKE ?', search_term).pluck(:id)
        collection_ids = Collection.where('title LIKE ?', search_term).pluck(:id)

        @taggings = @taggings.where(
          "(taggable_type = 'Manifestation' AND taggable_id IN (?)) OR " \
          "(taggable_type = 'Authority' AND taggable_id IN (?)) OR " \
          "(taggable_type = 'Collection' AND taggable_id IN (?))",
          manifestation_ids.presence || [0],
          authority_ids.presence || [0],
          collection_ids.presence || [0]
        )
      end

      # Filter by tag name
      if params[:tag_q].present?
        tag_search = "%#{params[:tag_q]}%"
        @taggings = @taggings.joins(tag: :tag_names)
                             .where('tag_names.name LIKE ?', tag_search)
                             .distinct
      end

      # Filter by status (default to approved)
      status_filter = params[:status].presence || 'approved'
      @taggings = @taggings.where(status: status_filter) unless status_filter == ''

      @taggings = @taggings.page(params[:page]).per(25)
      @page_title = t('.title')
    end

    def show
      @page_title = t('.title', id: @tagging.id)
    end

    def destroy
      respond_to do |format|
        if @tagging.destroy
          format.html { redirect_to admin_taggings_path, notice: t(:deleted_successfully) }
          format.js { render layout: false }
        else
          format.html { redirect_to admin_taggings_path, alert: t('admin.taggings.destroy_failed') }
          format.js { render js: "alert('#{t('admin.taggings.destroy_failed')}');", layout: false }
        end
      end
    end

    private

    def set_tagging
      @tagging = Tagging.find(params[:id])
    end

    def check_moderate_tags_permission
      return if current_user&.editor? && current_user.has_bit?('moderate_tags')

      redirect_to '/', flash: { error: t('admin.taggings.no_permission') }
    end
  end
end
