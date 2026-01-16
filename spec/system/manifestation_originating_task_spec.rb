# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Manifestation originating task link', type: :system, js: true do
  let(:user) { create(:user) }
  let(:editor) { create(:user, :edit_catalog) }
  let!(:work) { create(:work) }
  let!(:expression) { create(:expression, work: work) }
  let!(:manifestation) { create(:manifestation, expression: expression) }

  def login_as_editor
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(editor)
    editor
  end

  def login_as_regular_user
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    user
  end

  context 'when manifestation was created through an Ingestible with originating_task' do
    let!(:ingestible) do
      create(:ingestible,
             originating_task: 'https://example.com/task/123',
             ingested_changes: { texts: [[manifestation.id, manifestation.title, 'Author']] }.to_json)
    end

    context 'when user is an editor with edit_catalog permission' do
      before do
        login_as_editor
        visit manifestation_path(id: manifestation.id)
      end

      it 'shows a button to fetch originating task' do
        expect(page).to have_css('#originating-task-btn')
        expect(page).to have_content(I18n.t(:find_originating_task))
      end

      it 'displays the originating task link after clicking the button' do
        find('#originating-task-btn a').click

        # Wait for AJAX to complete
        expect(page).to have_link(I18n.t(:originating_task), href: 'https://example.com/task/123', wait: 5)
        expect(page).not_to have_css('#originating-task-btn')
      end
    end

    context 'when user does not have edit_catalog permission' do
      before do
        login_as_regular_user
        visit manifestation_path(id: manifestation.id)
      end

      it 'does not show the originating task button' do
        expect(page).not_to have_css('#originating-task-btn')
        expect(page).not_to have_content(I18n.t(:find_originating_task))
      end
    end

    context 'when user is not logged in' do
      before do
        visit manifestation_path(id: manifestation.id)
      end

      it 'does not show the originating task button' do
        expect(page).not_to have_css('#originating-task-btn')
        expect(page).not_to have_content(I18n.t(:find_originating_task))
      end
    end
  end

  context 'when manifestation was not created through an Ingestible' do
    before do
      login_as_editor
      visit manifestation_path(id: manifestation.id)
    end

    it 'shows the button but displays "not found" message when clicked' do
      expect(page).to have_css('#originating-task-btn')

      find('#originating-task-btn a').click

      # Wait for AJAX to complete
      expect(page).to have_content(I18n.t(:originating_task_not_found), wait: 5)
      expect(page).not_to have_css('#originating-task-btn')
      expect(page).not_to have_link(I18n.t(:originating_task))
    end
  end

  context 'when Ingestible exists but has no originating_task' do
    let!(:ingestible) do
      create(:ingestible,
             originating_task: nil,
             ingested_changes: { texts: [[manifestation.id, manifestation.title, 'Author']] }.to_json)
    end

    before do
      login_as_editor
      visit manifestation_path(id: manifestation.id)
    end

    it 'shows the button but displays "not found" message when clicked' do
      expect(page).to have_css('#originating-task-btn')

      find('#originating-task-btn a').click

      # Wait for AJAX to complete
      expect(page).to have_content(I18n.t(:originating_task_not_found), wait: 5)
      expect(page).not_to have_css('#originating-task-btn')
      expect(page).not_to have_link(I18n.t(:originating_task))
    end
  end
end
