require 'rails_helper'

RSpec.describe ExternalLinksController, type: :controller do
  let(:user) { create(:user) }
  let(:moderator) { create(:user, :editor, editor_bits: ['moderate_links']) }
  let(:authority) { create(:authority) }
  let(:manifestation) { create(:manifestation) }

  describe 'POST #propose' do
    context 'when user is logged in' do
      before { sign_in user }

      it 'creates a new external link with submitted status' do
        expect {
          post :propose, params: {
            url: 'https://example.com/test',
            linktype: 'wikipedia',
            description: 'Test link',
            linkable_type: 'Authority',
            linkable_id: authority.id,
            ziburit: 'Bialik',
            proposer_email: user.email
          }, xhr: true
        }.to change(ExternalLink, :count).by(1)

        link = ExternalLink.last
        expect(link.url).to eq('https://example.com/test')
        expect(link.linktype).to eq('wikipedia')
        expect(link.description).to eq('Test link')
        expect(link.status).to eq('submitted')
        expect(link.linkable_type).to eq('Authority')
        expect(link.linkable_id).to eq(authority.id)
        expect(link.proposer_id).to eq(user.id)
        expect(link.proposer_email).to eq(user.email)
      end

      it 'rejects proposal without ziburit field' do
        expect {
          post :propose, params: {
            url: 'https://example.com/spam',
            linktype: 'other',
            description: 'Spam link',
            linkable_type: 'Authority',
            linkable_id: authority.id,
            ziburit: '' # Empty ziburit
          }, xhr: true
        }.not_to change(ExternalLink, :count)

        expect(response.body).to include(I18n.t('propose_link.error'))
      end

      it 'rejects proposal with missing required fields' do
        expect {
          post :propose, params: {
            url: '',
            linktype: 'wikipedia',
            description: 'Test',
            linkable_type: 'Authority',
            linkable_id: authority.id,
            ziburit: 'Bialik'
          }, xhr: true
        }.not_to change(ExternalLink, :count)
      end

      it 'works for different linkable types' do
        post :propose, params: {
          url: 'https://example.com/manifestation',
          linktype: 'blog',
          description: 'Blog post about this text',
          linkable_type: 'Manifestation',
          linkable_id: manifestation.id,
          ziburit: 'Bialik'
        }, xhr: true

        link = ExternalLink.last
        expect(link.linkable_type).to eq('Manifestation')
        expect(link.linkable_id).to eq(manifestation.id)
      end
    end

    context 'when user is not logged in' do
      it 'denies access' do
        post :propose, params: {
          url: 'https://example.com/test',
          linktype: 'wikipedia',
          description: 'Test',
          linkable_type: 'Authority',
          linkable_id: authority.id,
          ziburit: 'Bialik'
        }, xhr: true

        expect(response.body).to include(I18n.t(:must_login_for_this))
      end
    end
  end

  describe 'GET #moderate' do
    let!(:submitted_links) do
      create_list(:external_link, 3,
                  linkable: authority,
                  status: :submitted)
    end

    let!(:approved_link) do
      create(:external_link,
             linkable: authority,
             status: :approved)
    end

    context 'with moderate_links permission' do
      before { sign_in moderator }

      it 'displays only submitted links' do
        get :moderate

        expect(assigns(:submitted_links)).to match_array(submitted_links)
        expect(assigns(:submitted_links)).not_to include(approved_link)
        expect(assigns(:total_count)).to eq(3)
      end

      it 'paginates results' do
        create_list(:external_link, 25, linkable: authority, status: :submitted)

        get :moderate

        expect(assigns(:submitted_links).count).to eq(20) # Default per page
      end
    end

    context 'without moderate_links permission' do
      before { sign_in user }

      it 'redirects with error' do
        get :moderate

        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq(I18n.t(:not_an_editor))
      end
    end

    context 'when not logged in' do
      it 'redirects to login' do
        get :moderate

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'POST #approve' do
    let(:link) { create(:external_link, status: :submitted, proposer_email: 'test@example.com') }

    before { sign_in moderator }

    it 'changes link status to approved' do
      post :approve, params: { id: link.id }, xhr: true

      expect(link.reload.status).to eq('approved')
    end

    it 'sends approval email' do
      expect(LinkProposalMailer).to receive(:send_or_queue).with(:approved, link.proposer_email, link)

      post :approve, params: { id: link.id }, xhr: true
    end

    it 'returns JavaScript to hide the link' do
      post :approve, params: { id: link.id }, xhr: true

      expect(response.body).to include("$('#link_#{link.id}').fadeOut();")
    end
  end

  describe 'POST #reject' do
    let(:link) { create(:external_link, status: :submitted, proposer_email: 'test@example.com') }

    before { sign_in moderator }

    it 'changes link status to rejected' do
      post :reject, params: { id: link.id, note: 'Not relevant' }, xhr: true

      expect(link.reload.status).to eq('rejected')
    end

    it 'sends rejection email with moderator note' do
      expect(LinkProposalMailer).to receive(:send_or_queue)
        .with(:rejected, link.proposer_email, link, 'Not relevant')

      post :reject, params: { id: link.id, note: 'Not relevant' }, xhr: true
    end

    it 'sends rejection email without note if not provided' do
      expect(LinkProposalMailer).to receive(:send_or_queue)
        .with(:rejected, link.proposer_email, link, nil)

      post :reject, params: { id: link.id }, xhr: true
    end
  end

  describe 'POST #escalate' do
    let(:link) { create(:external_link, status: :submitted) }

    before { sign_in moderator }

    it 'changes link status to escalated' do
      post :escalate, params: { id: link.id }, xhr: true

      expect(link.reload.status).to eq('escalated')
    end

    it 'does not send email' do
      expect(LinkProposalMailer).not_to receive(:send_or_queue)

      post :escalate, params: { id: link.id }, xhr: true
    end
  end
end
