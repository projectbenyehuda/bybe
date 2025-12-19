# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Anthology tagging', type: :system, js: true do
  let(:user) { create(:user) }
  let(:anthology) { create(:anthology, access: :pub) }
  let!(:approved_tag) { create(:tag, status: :approved, name: 'Fiction') }
  let!(:approved_tagging) { create(:tagging, taggable: anthology, tag: approved_tag, status: :approved) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    visit anthology_path(anthology)
  end

  describe 'viewing existing tags' do
    it 'displays the tags sidebar' do
      expect(page).to have_css('.left-side-card-v02')
      expect(page).to have_content(I18n.t(:tags))
    end

    it 'shows approved tags' do
      within('#taggings') do
        expect(page).to have_link('Fiction', href: tag_path(approved_tag.id))
      end
    end

    it 'shows the suggest new tag button' do
      expect(page).to have_button(I18n.t(:suggest_new_tag))
    end
  end

  describe 'when no tags exist' do
    let(:anthology_without_tags) { create(:anthology, access: :pub) }

    before do
      visit anthology_path(anthology_without_tags)
    end

    it 'shows "no tags yet" message' do
      within('#taggings') do
        expect(page).to have_content(I18n.t(:no_tags_yet, taggee: I18n.t(:this_item)))
      end
    end
  end
end
