require 'rails_helper'

RSpec.describe 'Link Moderation System', type: :system, js: true do
  let(:moderator) { create(:user, :editor, editor_bits: ['moderate_links']) }
  let(:regular_user) { create(:user) }
  let(:authority) { create(:authority) }

  let!(:submitted_link1) do
    create(:external_link,
           linkable: authority,
           status: :submitted,
           url: 'https://example.com/link1',
           description: 'Test link 1',
           linktype: :wikipedia,
           proposer_email: 'proposer@example.com')
  end

  let!(:submitted_link2) do
    create(:external_link,
           linkable: authority,
           status: :submitted,
           url: 'https://example.com/link2',
           description: 'Test link 2',
           linktype: :blog,
           proposer_email: 'proposer2@example.com')
  end

  describe 'Access control' do
    it 'allows access to users with moderate_links bit' do
      login_as(moderator, scope: :user)
      visit moderate_external_links_path

      expect(page).to have_content(I18n.t('moderate_links.title'))
      expect(page).to have_content('Test link 1')
      expect(page).to have_content('Test link 2')
    end

    it 'denies access to users without moderate_links bit' do
      login_as(regular_user, scope: :user)
      visit moderate_external_links_path

      expect(page).to have_content(I18n.t(:not_an_editor))
      expect(current_path).to eq(root_path)
    end

    it 'denies access to non-logged-in users' do
      visit moderate_external_links_path

      expect(current_path).not_to eq(moderate_external_links_path)
    end
  end

  describe 'Moderation view', :logged_in do
    before do
      login_as(moderator, scope: :user)
      visit moderate_external_links_path
    end

    it 'displays submitted links with all details' do
      expect(page).to have_content(I18n.t('moderate_links.total_submitted', count: 2))

      # Check link 1
      within("#link_#{submitted_link1.id}") do
        expect(page).to have_content('proposer@example.com')
        expect(page).to have_content(I18n.t(:wikipedia))
        expect(page).to have_content('Test link 1')
        expect(page).to have_link(I18n.t('moderate_links.open_link'), href: submitted_link1.url)
        expect(page).to have_button(I18n.t('moderate_links.approve'))
        expect(page).to have_button(I18n.t('moderate_links.reject'))
        expect(page).to have_button(I18n.t('moderate_links.escalate'))
      end

      # Check link 2
      within("#link_#{submitted_link2.id}") do
        expect(page).to have_content('proposer2@example.com')
        expect(page).to have_content(I18n.t(:blog))
        expect(page).to have_content('Test link 2')
      end
    end

    it 'approves a link' do
      within("#link_#{submitted_link1.id}") do
        accept_confirm do
          click_button I18n.t('moderate_links.approve')
        end
      end

      sleep 0.5 # Wait for AJAX

      # Link should be approved
      expect(submitted_link1.reload.status).to eq('approved')

      # Link should fade out from the list
      expect(page).not_to have_selector("#link_#{submitted_link1.id}", visible: true)
    end

    it 'rejects a link with moderator note' do
      # Mock the prompt for rejection note
      page.execute_script("window.prompt = function() { return 'This link is not relevant'; }")

      within("#link_#{submitted_link1.id}") do
        find('.reject-link-btn').click
      end

      sleep 0.5 # Wait for AJAX

      # Link should be rejected
      expect(submitted_link1.reload.status).to eq('rejected')

      # Link should fade out
      expect(page).not_to have_selector("#link_#{submitted_link1.id}", visible: true)
    end

    it 'escalates a link' do
      within("#link_#{submitted_link1.id}") do
        accept_confirm do
          click_button I18n.t('moderate_links.escalate')
        end
      end

      sleep 0.5 # Wait for AJAX

      # Link should be escalated
      expect(submitted_link1.reload.status).to eq('escalated')
    end
  end

  describe 'Admin dashboard link' do
    before do
      login_as(moderator, scope: :user)
    end

    it 'shows moderation link with count on admin dashboard' do
      visit admin_index_path

      expect(page).to have_link(I18n.t('moderate_links.title'), href: moderate_external_links_path)
      expect(page).to have_content(I18n.t('moderate_links.dashboard_count', count: 2))
    end
  end
end
