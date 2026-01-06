require 'rails_helper'

RSpec.describe 'External Link Proposal', type: :system, js: true do
  let(:user) { create(:user) }
  let(:authority) { create(:authority) }

  before do
    # Log in the user
    # NOTE: Cookie-based login currently fails in Chrome 143+
    # TODO: Replace with proper OmniAuth test helper or Devise test helpers
    visit '/'
    page.driver.browser.manage.add_cookie(name: '_bybe_session', value: Base64.encode64({ user_id: user.id }.to_json), domain: '127.0.0.1')
    visit authority_path(authority)
  end

  describe 'proposing a new link' do
    it 'opens the proposal modal when clicking suggest link' do
      # Find and click the "suggest new link" button
      within('#external_links_panel') do
        click_link I18n.t(:suggest_new_links)
      end

      # Modal should be visible
      expect(page).to have_selector('#proposeLinkDlg', visible: true)
      expect(page).to have_content(I18n.t('propose_link.title'))
    end

    it 'validates required fields' do
      # Open the modal
      within('#external_links_panel') do
        click_link I18n.t(:suggest_new_links)
      end

      # Submit without filling fields
      within('#proposeLinkDlg') do
        fill_in 'ziburit', with: 'Bialik'  # Fill spam check
        click_button I18n.t('propose_link.submit')
      end

      # Should show validation error
      expect(page.driver.browser.switch_to.alert.text).to include(I18n.t('propose_link.missing_url'))
      page.driver.browser.switch_to.alert.accept
    end

    it 'validates ziburit spam check field' do
      # Open the modal
      within('#external_links_panel') do
        click_link I18n.t(:suggest_new_links)
      end

      # Submit without ziburit
      within('#proposeLinkDlg') do
        fill_in 'url', with: 'https://example.com/spam'
        select I18n.t('wikipedia'), from: 'linktype'
        fill_in 'description', with: 'Spam link'
        # Don't fill ziburit
        click_button I18n.t('propose_link.submit')
      end

      # Should show ziburit validation error
      expect(page.driver.browser.switch_to.alert.text).to include(I18n.t('propose_link.missing_ziburit'))
      page.driver.browser.switch_to.alert.accept
    end

    it 'successfully submits a link proposal and shows it as pending' do
      # Open the modal
      within('#external_links_panel') do
        click_link I18n.t(:suggest_new_links)
      end

      # Fill in the form
      within('#proposeLinkDlg') do
        fill_in 'url', with: 'https://he.wikipedia.org/wiki/Example'
        select I18n.t('wikipedia'), from: 'linktype'
        fill_in 'description', with: 'Wikipedia entry for this author'
        fill_in 'ziburit', with: 'Bialik'
        click_button I18n.t('propose_link.submit')
      end

      # Modal should close
      expect(page).not_to have_selector('#proposeLinkDlg', visible: true)

      # The external links panel should be updated with the pending link
      within('#external_links_panel') do
        # Should show "Pending Links" section
        expect(page).to have_content(I18n.t(:pending_links))
        # Should show the proposed link
        expect(page).to have_content('Wikipedia entry for this author')
        expect(page).to have_content(I18n.t('wikipedia'))
        # Should show pending icon
        expect(page).to have_selector('.by-icon-v02.pending-tag')
        # Should have a cancel button
        expect(page).to have_button('×')
      end

      # Verify the link was created in the database
      link = ExternalLink.last
      expect(link.url).to eq('https://he.wikipedia.org/wiki/Example')
      expect(link.linktype).to eq('wikipedia')
      expect(link.description).to eq('Wikipedia entry for this author')
      expect(link.status).to eq('submitted')
      expect(link.proposer_id).to eq(user.id)
      expect(link.proposer_email).to eq(user.email)
      expect(link.linkable).to eq(authority)
    end

    it 'allows user to cancel their own pending link' do
      # Create a pending link
      link = create(:external_link,
                    linkable: authority,
                    status: :submitted,
                    proposer_id: user.id,
                    proposer_email: user.email,
                    description: 'Test pending link')

      # Refresh the page to see the pending link
      visit authority_path(authority)

      within('#external_links_panel') do
        expect(page).to have_content('Test pending link')

        # Click the cancel button (changed from link to button_to for Rails UJS compatibility)
        within("li[data-link-id='#{link.id}']") do
          click_button '×'
        end
      end

      # Wait for the AJAX request to complete and the panel to update
      sleep 0.5

      # The pending link should be removed
      within('#external_links_panel') do
        expect(page).not_to have_content('Test pending link')
        # If that was the only pending link, the pending section should be gone
        if user.external_links.where(status: :submitted).count == 0
          expect(page).not_to have_content(I18n.t(:pending_links))
        end
      end

      # Verify the link was deleted from the database
      expect(ExternalLink.exists?(link.id)).to be false
    end
  end

  describe 'viewing approved and pending links' do
    let!(:approved_link) do
      create(:external_link,
             linkable: authority,
             status: :approved,
             linktype: :wikipedia,
             description: 'Approved Wikipedia link')
    end

    let!(:my_pending_link) do
      create(:external_link,
             linkable: authority,
             status: :submitted,
             proposer_id: user.id,
             linktype: :blog,
             description: 'My pending blog link')
    end

    let!(:other_user_pending_link) do
      other_user = create(:user)
      create(:external_link,
             linkable: authority,
             status: :submitted,
             proposer_id: other_user.id,
             linktype: :youtube,
             description: 'Other user pending link')
    end

    it 'shows approved links to all users' do
      visit authority_path(authority)

      within('#external_links_panel') do
        expect(page).to have_content('Approved Wikipedia link')
      end
    end

    it 'shows only user\'s own pending links' do
      visit authority_path(authority)

      within('#external_links_panel') do
        # Should see own pending link
        expect(page).to have_content('My pending blog link')
        # Should NOT see other user's pending link
        expect(page).not_to have_content('Other user pending link')
      end
    end

    it 'admin sees all pending links' do
      admin = create(:user, :admin)
      # Log out and log in as admin
      page.driver.browser.manage.delete_all_cookies
      page.driver.browser.manage.add_cookie(name: '_bybe_session', value: Base64.encode64({ user_id: admin.id }.to_json), domain: '127.0.0.1')

      visit authority_path(authority)

      within('#external_links_panel') do
        # Should see all pending links
        expect(page).to have_content('My pending blog link')
        expect(page).to have_content('Other user pending link')
      end
    end
  end

  describe 'link proposal on different linkable types' do
    let(:manifestation) { create(:manifestation) }
    let(:collection) { create(:collection) }

    it 'works for manifestations' do
      visit manifestation_path(manifestation)

      within('#external_links_panel') do
        click_link I18n.t(:suggest_new_links)
      end

      within('#proposeLinkDlg') do
        fill_in 'url', with: 'https://example.com/manifestation'
        select I18n.t('blog'), from: 'linktype'
        fill_in 'description', with: 'Blog post about this work'
        fill_in 'ziburit', with: 'Bialik'
        click_button I18n.t('propose_link.submit')
      end

      # Verify the link was created for the manifestation
      link = ExternalLink.last
      expect(link.linkable_type).to eq('Manifestation')
      expect(link.linkable_id).to eq(manifestation.id)
    end

    it 'works for collections' do
      visit collection_path(collection)

      within('#external_links_panel') do
        click_link I18n.t(:suggest_new_links)
      end

      within('#proposeLinkDlg') do
        fill_in 'url', with: 'https://example.com/collection'
        select I18n.t('dedicated_site'), from: 'linktype'
        fill_in 'description', with: 'Website about this collection'
        fill_in 'ziburit', with: 'Bialik'
        click_button I18n.t('propose_link.submit')
      end

      # Verify the link was created for the collection
      link = ExternalLink.last
      expect(link.linkable_type).to eq('Collection')
      expect(link.linkable_id).to eq(collection.id)
    end
  end
end
