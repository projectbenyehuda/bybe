require 'rails_helper'

RSpec.describe 'Link Proposal System', type: :system, js: true do
  let(:authority) { create(:authority, :with_toc) }
  let(:manifestation) { create(:manifestation) }
  let(:collection) { create(:collection) }
  let(:user) { create(:user) }

  describe 'Login check for proposal link' do
    context 'when user is not logged in' do
      it 'shows login message when clicking propose link on author page' do
        visit authority_path(authority)

        expect(page).to have_content(I18n.t(:suggest_new_links))

        # Click the propose link
        find('.must_login').click

        # Should show login alert
        expect(page.driver.browser.switch_to.alert.text).to eq(I18n.t(:must_login_for_this))
        page.driver.browser.switch_to.alert.accept
      end

      it 'shows login message when clicking propose link on manifestation page' do
        visit read_path(manifestation)

        find('.must_login', text: I18n.t(:suggest_new_links)).click

        expect(page.driver.browser.switch_to.alert.text).to eq(I18n.t(:must_login_for_this))
        page.driver.browser.switch_to.alert.accept
      end

      it 'shows login message when clicking propose link on collection page' do
        visit collection_path(collection)

        find('.must_login', text: I18n.t(:suggest_new_links)).click

        expect(page.driver.browser.switch_to.alert.text).to eq(I18n.t(:must_login_for_this))
        page.driver.browser.switch_to.alert.accept
      end
    end
  end

  describe 'Link proposal modal for logged-in users', :logged_in do
    before do
      login_as(user, scope: :user)
    end

    context 'on author page' do
      it 'opens proposal modal and submits successfully' do
        visit authority_path(authority)

        # Click the propose link
        find('[data-toggle="modal"][data-target="#proposeLinkDlg"]').click

        # Wait for modal to appear
        expect(page).to have_selector('#proposeLinkDlg', visible: true)
        expect(page).to have_content(I18n.t('propose_link.title'))

        # Fill in the form
        within('#proposeLinkDlg') do
          fill_in 'url', with: 'https://example.com/author-page'
          select I18n.t(:wikipedia), from: 'linktype'
          fill_in 'description', with: 'Wikipedia entry for this author'
          fill_in 'ziburit', with: 'Bialik'
        end

        # Submit the form
        expect {
          within('#proposeLinkDlg') do
            click_button I18n.t('propose_link.submit')
          end
          sleep 0.5 # Wait for AJAX
        }.to change(ExternalLink, :count).by(1)

        # Check the created link
        link = ExternalLink.last
        expect(link.url).to eq('https://example.com/author-page')
        expect(link.linktype).to eq('wikipedia')
        expect(link.description).to eq('Wikipedia entry for this author')
        expect(link.status).to eq('submitted')
        expect(link.linkable_type).to eq('Authority')
        expect(link.linkable_id).to eq(authority.id)
        expect(link.proposer_id).to eq(user.id)
        expect(link.proposer_email).to eq(user.email)

        # Modal should be hidden and success message shown
        expect(page).to have_selector('#proposeLinkDlg', visible: false)
      end

      it 'validates required fields' do
        visit authority_path(authority)

        find('[data-toggle="modal"][data-target="#proposeLinkDlg"]').click

        # Try to submit without filling required fields
        within('#proposeLinkDlg') do
          click_button I18n.t('propose_link.submit')
        end

        # Should show error (browser validation will prevent submission)
        expect(ExternalLink.count).to eq(0)
      end

      it 'validates ziburit spam prevention field' do
        visit authority_path(authority)

        find('[data-toggle="modal"][data-target="#proposeLinkDlg"]').click

        within('#proposeLinkDlg') do
          fill_in 'url', with: 'https://example.com/spam'
          select I18n.t(:other), from: 'linktype'
          fill_in 'description', with: 'Spam link'
          # Don't fill ziburit field

          click_button I18n.t('propose_link.submit')
          sleep 0.5
        end

        expect(ExternalLink.count).to eq(0)
      end
    end

    context 'on manifestation page' do
      it 'proposes link for manifestation' do
        visit read_path(manifestation)

        find('[data-toggle="modal"][data-target="#proposeLinkDlg"]').click

        within('#proposeLinkDlg') do
          fill_in 'url', with: 'https://example.com/text-analysis'
          select I18n.t(:blog), from: 'linktype'
          fill_in 'description', with: 'Analysis of this text'
          fill_in 'ziburit', with: 'Bialik'

          click_button I18n.t('propose_link.submit')
          sleep 0.5
        end

        link = ExternalLink.last
        expect(link.linkable_type).to eq('Manifestation')
        expect(link.linkable_id).to eq(manifestation.id)
      end
    end

    context 'on collection page' do
      it 'proposes link for collection' do
        visit collection_path(collection)

        find('[data-toggle="modal"][data-target="#proposeLinkDlg"]').click

        within('#proposeLinkDlg') do
          fill_in 'url', with: 'https://example.com/collection-info'
          select I18n.t(:dedicated_site), from: 'linktype'
          fill_in 'description', with: 'Website about this collection'
          fill_in 'ziburit', with: 'Bialik'

          click_button I18n.t('propose_link.submit')
          sleep 0.5
        end

        link = ExternalLink.last
        expect(link.linkable_type).to eq('Collection')
        expect(link.linkable_id).to eq(collection.id)
      end
    end
  end
end
