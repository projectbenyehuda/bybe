# frozen_string_literal: true

# Admin controller for managing Projects
module Admin
  # Projects controller handles CRUD operations for Projects
  class ProjectsController < ApplicationController
    before_action :require_admin
    before_action :set_project, only: %i(show edit update destroy)

    layout 'backend'

    def index
      @projects = Project.order(created_at: :desc).page(params[:page])
      @page_title = t('projects.index.title')
    end

    def show
      @page_title = @project.name
    end

    def new
      @project = Project.new
      @page_title = t('projects.new.title')
    end

    def edit
      @page_title = t('projects.edit.title')
    end

    def create
      @project = Project.new(project_params)

      if @project.save
        redirect_to admin_project_path(@project), notice: t(:created_successfully)
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @project.update(project_params)
        redirect_to admin_project_path(@project), notice: t(:updated_successfully)
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @project.destroy
      redirect_to admin_projects_path, notice: t(:deleted_successfully)
    end

    private

    def set_project
      @project = Project.find(params[:id])
    end

    def project_params
      params.require(:project).permit(
        :name,
        :description,
        :start_date,
        :end_date,
        :contact_person_name,
        :contact_person_phone,
        :contact_person_email,
        :comments,
        :default_external_link,
        :default_link_description
      )
    end
  end
end
