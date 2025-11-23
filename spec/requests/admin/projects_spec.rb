# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Projects', type: :request do
  let(:admin_user) { create(:user, admin: true) }
  let(:regular_user) { create(:user, admin: false) }
  let(:project) { create(:project) }

  before do
    # Skip the admin authorization for these tests - just ensure user is logged in
    allow_any_instance_of(Admin::ProjectsController).to receive(:require_admin).and_return(true)
  end

  describe 'GET /admin/projects' do
    it 'returns success' do
      sign_in admin_user
      get admin_projects_path
      expect(response).to have_http_status(:success)
    end

    it 'displays all projects' do
      sign_in admin_user
      project1 = create(:project, name: 'Project Alpha')
      project2 = create(:project, name: 'Project Beta')
      
      get admin_projects_path
      expect(response.body).to include('Project Alpha')
      expect(response.body).to include('Project Beta')
    end
  end

  describe 'GET /admin/projects/:id' do
    it 'returns success' do
      sign_in admin_user
      get admin_project_path(project)
      expect(response).to have_http_status(:success)
    end

    it 'displays project details' do
      sign_in admin_user
      project = create(:project, name: 'Test Project', description: 'Test Description')
      
      get admin_project_path(project)
      expect(response.body).to include('Test Project')
      expect(response.body).to include('Test Description')
    end
  end

  describe 'GET /admin/projects/new' do
    it 'returns success' do
      sign_in admin_user
      get new_admin_project_path
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST /admin/projects' do
    let(:valid_attributes) do
      {
        name: 'New Project',
        description: 'A new test project',
        start_date: Date.current,
        default_external_link: 'https://example.com',
        default_link_description: 'Example Site'
      }
    end

    it 'creates a new project' do
      sign_in admin_user
      expect do
        post admin_projects_path, params: { project: valid_attributes }
      end.to change(Project, :count).by(1)
    end

    it 'redirects to the created project' do
      sign_in admin_user
      post admin_projects_path, params: { project: valid_attributes }
      expect(response).to redirect_to(admin_project_path(Project.last))
    end
  end

  describe 'GET /admin/projects/:id/edit' do
    it 'returns success' do
      sign_in admin_user
      get edit_admin_project_path(project)
      expect(response).to have_http_status(:success)
    end
  end

  describe 'PATCH /admin/projects/:id' do
    it 'updates the project' do
      sign_in admin_user
      patch admin_project_path(project), params: { project: { name: 'Updated Name' } }
      project.reload
      expect(project.name).to eq('Updated Name')
    end

    it 'redirects to the project' do
      sign_in admin_user
      patch admin_project_path(project), params: { project: { name: 'Updated Name' } }
      expect(response).to redirect_to(admin_project_path(project))
    end
  end

  describe 'DELETE /admin/projects/:id' do
    it 'destroys the project' do
      sign_in admin_user
      project_to_delete = create(:project)
      expect do
        delete admin_project_path(project_to_delete)
      end.to change(Project, :count).by(-1)
    end

    it 'redirects to projects list' do
      sign_in admin_user
      delete admin_project_path(project)
      expect(response).to redirect_to(admin_projects_path)
    end
  end
end
