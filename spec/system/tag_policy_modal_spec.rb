# frozen_string_literal: true

require 'rails_helper'

describe 'Tag policy prompt on "Add Tag"', :js do
  let(:user) { create(:user) }

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  shared_examples 'prompts to accept the tag policy' do
    it 'shows the tag policy modal instead of doing nothing' do
      visit page_path

      expect(page).to have_no_css('#tagPolicyDlg.show')

      find('#initiate-add-tag').click

      expect(page).to have_css('#tagPolicyDlg.show', wait: 5)
      within '#tagPolicyDlg' do
        expect(page).to have_content(I18n.t(:i_understand_and_accept))
        expect(page).to have_button(I18n.t(:can_proceed))
      end
    end
  end

  context 'when on the author TOC page' do
    let(:author) { create(:authority, name: 'Test Author', gender: 'male') }
    let(:page_path) { authority_path(author) }

    it_behaves_like 'prompts to accept the tag policy'
  end

  context 'when on the collection page' do
    let(:collection) { create(:collection, title: 'Test Collection') }
    let(:page_path) { collection_path(collection) }

    it_behaves_like 'prompts to accept the tag policy'
  end

  context 'when on the anthology page' do
    let(:anthology) { create(:anthology, access: :pub) }
    let(:page_path) { anthology_path(anthology) }

    it_behaves_like 'prompts to accept the tag policy'
  end
end
