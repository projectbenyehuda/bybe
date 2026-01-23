# frozen_string_literal: true

# Admin controller for managing Tags
module Admin
  # Tags controller handles CRUD operations for Tags and their aliases (TagNames)
  class TagsController < ApplicationController
    before_action -> { require_editor('moderate_tags') },
                  only: %i(index show new create edit update destroy add_alias make_primary_alias remove_alias)
    before_action :set_tag, only: %i(show edit update destroy)

    layout 'backend'

    def index
      @tags = Tag.includes(:tag_names, :creator).order(created_at: :desc)

      # Filter by search query
      if params[:q].present?
        sanitized_query = ActiveRecord::Base.sanitize_sql_like(params[:q])
        search_term = "%#{sanitized_query}%"
        @tags = @tags.joins(:tag_names).where('tag_names.name LIKE ?', search_term).distinct
      end

      # Filter by status (default to approved)
      status_filter = params[:status].presence || 'approved'
      @tags = @tags.where(status: status_filter) unless status_filter == ''

      @tags = @tags.page(params[:page]).per(25)
      @page_title = t('.title')
    end

    def show
      @page_title = @tag.name
      @taggings_count = @tag.taggings.count
      @tag_names = @tag.tag_names.order(created_at: :asc)
    end

    def new
      @tag = Tag.new
      @page_title = t('.title')
    end

    def edit
      @page_title = t('.title')
      @tag_names = @tag.tag_names.order(created_at: :asc)
    end

    def create
      @tag = Tag.new(tag_params)
      @tag.creator = current_user

      if @tag.save
        # NOTE: primary TagName is automatically created by Tag model after_create callback
        redirect_to admin_tag_path(@tag), notice: t(:created_successfully)
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @tag.update(tag_params)
        # Update the primary tag name if the tag name changed
        primary_tag_name = @tag.tag_names.find_by(name: @tag.name)
        if primary_tag_name.nil? && @tag.tag_names.any?
          # If no tag name matches the tag's name, update the first one
          @tag.tag_names.first.update(name: @tag.name)
        end

        # Add new alias if alias_name parameter is provided
        if params[:alias_name].present?
          alias_name = params[:alias_name].to_s.strip
          @tag.tag_names.create(name: alias_name) if alias_name.present?
        end

        redirect_to admin_tag_path(@tag), notice: t(:updated_successfully)
      else
        @tag_names = @tag.tag_names.order(created_at: :asc)
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      # Check if there are any taggings
      taggings_count = @tag.taggings.count

      respond_to do |format|
        if @tag.destroy
          format.html do
            redirect_to admin_tags_path,
                        notice: t('admin.tags.destroyed_successfully', count: taggings_count)
          end
          format.js { render layout: false }
        else
          format.html do
            redirect_to admin_tags_path,
                        alert: t('admin.tags.destroy_failed')
          end
          format.js { render js: "alert('#{t('admin.tags.destroy_failed')}');", layout: false }
        end
      end
    end

    # Add a new alias (TagName) to the tag
    def add_alias
      @tag = Tag.find(params[:id])
      alias_name = params[:alias_name].to_s.strip

      if alias_name.blank?
        redirect_to edit_admin_tag_path(@tag), alert: t('admin.tags.alias_name_blank')
        return
      end

      tag_name = @tag.tag_names.build(name: alias_name)

      if tag_name.save
        redirect_to edit_admin_tag_path(@tag), notice: t('admin.tags.alias_added')
      else
        redirect_to edit_admin_tag_path(@tag), alert: t('admin.tags.alias_add_failed')
      end
    end

    # Make a TagName the primary name for the tag
    def make_primary_alias
      @tag = Tag.find(params[:id])
      tag_name = @tag.tag_names.find(params[:tag_name_id])

      old_name = @tag.name
      new_name = tag_name.name

      # Update the tag's primary name
      if @tag.update(name: new_name)
        redirect_to edit_admin_tag_path(@tag),
                    notice: t('admin.tags.primary_alias_changed', old: old_name, new: new_name)
      else
        redirect_to edit_admin_tag_path(@tag), alert: t('admin.tags.primary_alias_change_failed')
      end
    end

    # Remove an alias (TagName) from the tag
    def remove_alias
      @tag = Tag.find(params[:id])
      tag_name = @tag.tag_names.find(params[:tag_name_id])

      # Don't allow removing the primary name if it's the only one
      if @tag.tag_names.one?
        redirect_to edit_admin_tag_path(@tag), alert: t('admin.tags.cannot_remove_last_alias')
        return
      end

      # Don't allow removing the primary name
      if tag_name.name == @tag.name
        redirect_to edit_admin_tag_path(@tag), alert: t('admin.tags.cannot_remove_primary_alias')
        return
      end

      if tag_name.destroy
        redirect_to edit_admin_tag_path(@tag), notice: t('admin.tags.alias_removed')
      else
        redirect_to edit_admin_tag_path(@tag), alert: t('admin.tags.alias_remove_failed')
      end
    end

    private

    def set_tag
      @tag = Tag.find(params[:id])
    end

    def tag_params
      params.expect(tag: %i(name status))
    end
  end
end
