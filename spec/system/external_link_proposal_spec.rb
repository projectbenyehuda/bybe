require 'rails_helper'

describe 'External Link Proposal' do
  let(:user) { create(:user) }
  let(:authority) { create(:authority) }

  before do
    # Mock current_user for system specs (works with js: true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    visit authority_path(authority)
  end

  describe 'proposing a new link' do
    it 'has a modal dialog with proposal form' do
      # Verify the modal exists in the DOM with all required form fields (including hidden elements)
      expect(page).to have_selector('#proposeLinkDlg', visible: :all)
      expect(page).to have_selector('#propose_link_form', visible: :all)
      expect(page).to have_selector('input[name="url"]', visible: :all)
      expect(page).to have_selector('select[name="linktype"]', visible: :all)
      expect(page).to have_selector('input[name="description"]', visible: :all)
      expect(page).to have_selector('input[name="ziburit"]', visible: :all)
      # The modal contains the correct title (even if not visibly rendered)
      expect(page.html).to include(I18n.t('propose_link.title'))
    end

    it 'validates required URL field', :js do
      # Test validation by submitting with missing URL - should show alert
      alert_message = accept_alert do
        # Submit form with missing URL via JavaScript
        page.execute_script("
          $.post($('#propose_link_form').attr('action'), {
            ziburit: 'Bialik',
            linktype: 'wikipedia',
            description: 'test',
            linkable_type: 'Authority',
            linkable_id: '1'
          });
        ")
        sleep 0.5  # Give AJAX time to respond
      end

      expect(alert_message).to include(I18n.t('propose_link.missing_url'))
    end

    it 'validates ziburit spam check field', :js do
      # Test ziburit validation by submitting without it - should show alert
      alert_message = accept_alert do
        # Submit form with missing ziburit via JavaScript
        page.execute_script("
          $.post($('#propose_link_form').attr('action'), {
            url: 'https://example.com/spam',
            linktype: 'wikipedia',
            description: 'Spam link',
            linkable_type: 'Authority',
            linkable_id: '1'
          });
        ")
        sleep 0.5  # Give AJAX time to respond
      end

      expect(alert_message).to include(I18n.t('propose_link.missing_ziburit'))
    end

    it 'successfully submits a link proposal and shows it as pending', :js do
      # Click on the parent div that has the Bootstrap data-toggle attribute
      within('#external_links_panel') do
        find('.metadata-link[data-toggle="modal"]').click
      end

      # Wait for modal to be visible
      expect(page).to have_selector('#proposeLinkDlg', visible: true, wait: 5)

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

    it 'allows user to cancel their own pending link', :js do
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
        if ExternalLink.where(proposer_id: user.id, status: :submitted).count == 0
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
      # Switch to admin user
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin)

      visit authority_path(authority)

      within('#external_links_panel') do
        # Should see all pending links
        expect(page).to have_content('My pending blog link')
        expect(page).to have_content('Other user pending link')
      end
    end
  end

  describe 'link proposal on different linkable types', :js do
    let(:manifestation) { create(:manifestation) }
    let(:collection) { create(:collection) }

    it 'works for manifestations' do
      visit manifestation_path(manifestation)

      # Click on the parent div that has the Bootstrap data-toggle attribute
      within('#external_links_panel') do
        find('.metadata-link[data-toggle="modal"]').click
      end

      # Wait for modal to be visible
      expect(page).to have_selector('#proposeLinkDlg', visible: true, wait: 5)

      within('#proposeLinkDlg') do
        fill_in 'url', with: 'https://example.com/manifestation'
        select I18n.t('blog'), from: 'linktype'
        fill_in 'description', with: 'Blog post about this work'
        fill_in 'ziburit', with: 'Bialik'
        click_button I18n.t('propose_link.submit')
      end

      # Wait for modal to close (indicates AJAX completed)
      expect(page).not_to have_selector('#proposeLinkDlg', visible: true, wait: 5)

      # Wait for the link to appear in the pending section
      within('#external_links_panel') do
        expect(page).to have_content('Blog post about this work', wait: 5)
      end

      # Verify the link was created for the manifestation
      link = ExternalLink.last
      expect(link.linkable_type).to eq('Manifestation')
      expect(link.linkable_id).to eq(manifestation.id)
    end

    it 'works for collections', :js do
      visit collection_path(collection)

      # Click on the parent div that has the Bootstrap data-toggle attribute
      within('#external_links_panel') do
        find('.metadata-link[data-toggle="modal"]').click
      end

      # Wait for modal to be visible
      expect(page).to have_selector('#proposeLinkDlg', visible: true, wait: 5)

      within('#proposeLinkDlg') do
        fill_in 'url', with: 'https://example.com/collection'
        select I18n.t('dedicated_site'), from: 'linktype'
        fill_in 'description', with: 'Website about this collection'
        fill_in 'ziburit', with: 'Bialik'
        click_button I18n.t('propose_link.submit')
      end

      # Wait for modal to close (indicates AJAX completed)
      expect(page).not_to have_selector('#proposeLinkDlg', visible: true, wait: 5)

      # Wait for the link to appear in the pending section
      within('#external_links_panel') do
        expect(page).to have_content('Website about this collection', wait: 5)
      end

      # Verify the link was created for the collection
      link = ExternalLink.last
      expect(link.linkable_type).to eq('Collection')
      expect(link.linkable_id).to eq(collection.id)
    end
  end
end
