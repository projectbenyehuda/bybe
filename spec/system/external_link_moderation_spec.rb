require 'rails_helper'

RSpec.describe 'External Link Moderation', type: :system, js: true do
  let(:moderator) { create(:user, :moderate_links) }
  let(:regular_user) { create(:user) }
  let(:authority) { create(:authority) }

  let!(:submitted_links) do
    3.times.map do |i|
      create(:external_link,
             linkable: authority,
             status: :submitted,
             proposer_id: regular_user.id,
             proposer_email: regular_user.email,
             description: "Submitted link #{i + 1}")
    end
  end

  let!(:approved_link) do
    create(:external_link,
           linkable: authority,
           status: :approved,
           description: 'Already approved link')
  end

  before do
    # Mock the mailer to avoid actually sending emails in tests
    allow(LinkProposalMailer).to receive(:send_or_queue)
  end

  describe 'accessing moderation interface' do
    it 'allows moderators to access the moderation page' do
      # Log in as moderator
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(moderator)
      visit moderate_external_links_path

      expect(page).to have_content(I18n.t('moderate_links.title'))
    end

    it 'denies access to regular users' do
      # Log in as regular user
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(regular_user)
      visit moderate_external_links_path

      # Should redirect to root with error
      expect(page).to have_current_path(root_path)
      expect(page).to have_content(I18n.t(:not_an_editor))
    end

    it 'denies access to non-logged-in users' do
      visit moderate_external_links_path

      # Should redirect to root with error
      expect(page).to have_current_path(root_path)
      expect(page).to have_content(I18n.t(:not_an_editor))
    end
  end

  describe 'viewing submitted links' do
    before do
      # Log in as moderator
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(moderator)
      visit moderate_external_links_path
    end

    it 'displays only submitted links' do
      submitted_links.each do |link|
        expect(page).to have_content(link.description)
        expect(page).to have_content(link.url)
      end

      # Should not show approved links
      expect(page).not_to have_content('Already approved link')
    end

    it 'shows link details including linkable information' do
      link = submitted_links.first
      expect(page).to have_content(link.linkable.name) if link.linkable.respond_to?(:name)
      expect(page).to have_content(I18n.t(link.linktype))
    end

    it 'displays total count of submitted links' do
      expect(page).to have_content("3") # Total count
    end
  end

  describe 'approving a link' do
    before do
      # Log in as moderator
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(moderator)
      visit moderate_external_links_path
    end

    it 'approves a link and sends notification' do
      link = submitted_links.first

      within("#link_#{link.id}") do
        click_button I18n.t(:approve)
      end

      # Wait for AJAX and animation
      sleep 0.5

      # Link should disappear from the list
      expect(page).not_to have_selector("#link_#{link.id}")

      # Verify the link was approved in the database
      link.reload
      expect(link.status).to eq('approved')

      # Verify email was sent
      expect(LinkProposalMailer).to have_received(:send_or_queue)
        .with(:approved, link.proposer_email, link)
    end
  end

  describe 'rejecting a link' do
    before do
      # Log in as moderator
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(moderator)
      visit moderate_external_links_path
    end

    it 'rejects a link with a note' do
      link = submitted_links.first

      within("#link_#{link.id}") do
        fill_in 'note', with: 'Not relevant to this author'
        click_button I18n.t(:reject)
      end

      # Wait for AJAX and animation
      sleep 0.5

      # Link should disappear from the list
      expect(page).not_to have_selector("#link_#{link.id}")

      # Verify the link was rejected in the database
      link.reload
      expect(link.status).to eq('rejected')

      # Verify email was sent with note
      expect(LinkProposalMailer).to have_received(:send_or_queue)
        .with(:rejected, link.proposer_email, link, 'Not relevant to this author')
    end

    it 'rejects a link without a note' do
      link = submitted_links.second

      within("#link_#{link.id}") do
        click_button I18n.t(:reject)
      end

      # Wait for AJAX and animation
      sleep 0.5

      # Link should disappear from the list
      expect(page).not_to have_selector("#link_#{link.id}")

      # Verify the link was rejected in the database
      link.reload
      expect(link.status).to eq('rejected')

      # Verify email was sent without note
      expect(LinkProposalMailer).to have_received(:send_or_queue)
        .with(:rejected, link.proposer_email, link, nil)
    end
  end

  describe 'escalating a link' do
    before do
      # Log in as moderator
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(moderator)
      visit moderate_external_links_path
    end

    it 'escalates a link without sending email' do
      link = submitted_links.last

      within("#link_#{link.id}") do
        click_button I18n.t(:escalate)
      end

      # Wait for AJAX
      sleep 0.5

      # Link should be marked as escalated (with CSS class)
      expect(page).to have_selector("#link_#{link.id}.escalated")

      # Verify the link was escalated in the database
      link.reload
      expect(link.status).to eq('escalated')

      # Verify NO email was sent
      expect(LinkProposalMailer).not_to have_received(:send_or_queue)
    end
  end

  describe 'pagination' do
    before do
      # Create many submitted links to test pagination
      25.times do |i|
        create(:external_link,
               linkable: authority,
               status: :submitted,
               description: "Pagination test link #{i + 1}")
      end

      # Log in as moderator
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(moderator)
      visit moderate_external_links_path
    end

    it 'displays 20 links per page by default' do
      # Should show 20 links (default per_page)
      expect(page).to have_selector('.link-item', count: 20)

      # Should have pagination controls
      expect(page).to have_link('2')  # Second page link
    end

    it 'navigates to second page' do
      click_link '2'

      # Should be on second page
      expect(page).to have_current_path(/page=2/)

      # Should show remaining links
      expect(page).to have_selector('.link-item', count: 8)  # 28 total - 20 on first page = 8
    end
  end
end
