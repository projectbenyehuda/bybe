require 'rails_helper'

RSpec.describe LinkProposalMailer, type: :mailer do
  let(:authority) { create(:authority, name: 'Test Author') }
  let(:manifestation) { create(:manifestation, title: 'Test Manifestation') }
  let(:collection) { create(:collection, title: 'Test Collection') }

  describe '#approved' do
    context 'with authority linkable' do
      let(:link) do
        create(:external_link,
               linkable: authority,
               url: 'https://en.wikipedia.org/wiki/Test',
               description: 'Wikipedia entry',
               linktype: :wikipedia,
               proposer_email: 'proposer@example.com',
               status: :approved)
      end

      let(:mail) { LinkProposalMailer.approved(link) }

      it 'sends to the proposer email' do
        expect(mail.to).to eq(['proposer@example.com'])
      end

      it 'has the correct subject' do
        expect(mail.subject).to eq(I18n.t('link_proposal_mailer.approved.subject'))
      end

      it 'includes link details in the body' do
        expect(mail.body.encoded).to include('https://en.wikipedia.org/wiki/Test')
        expect(mail.body.encoded).to include('Wikipedia entry')
        expect(mail.body.encoded).to include(I18n.t(:wikipedia))
      end

      it 'includes linkable information' do
        expect(mail.body.encoded).to include('Test Author')
      end

      it 'includes thank you message' do
        expect(mail.body.encoded).to include(I18n.t('link_proposal_mailer.approved.thanks'))
      end
    end

    context 'with manifestation linkable' do
      let(:link) do
        create(:external_link,
               linkable: manifestation,
               url: 'https://example.com/analysis',
               description: 'Analysis article',
               linktype: :blog,
               proposer_email: 'user@example.com',
               status: :approved)
      end

      let(:mail) { LinkProposalMailer.approved(link) }

      it 'includes manifestation title' do
        expect(mail.body.encoded).to include('Test Manifestation')
      end
    end

    context 'with collection linkable' do
      let(:link) do
        create(:external_link,
               linkable: collection,
               url: 'https://example.com/collection-info',
               description: 'Collection website',
               linktype: :dedicated_site,
               proposer_email: 'collector@example.com',
               status: :approved)
      end

      let(:mail) { LinkProposalMailer.approved(link) }

      it 'includes collection title' do
        expect(mail.body.encoded).to include('Test Collection')
      end
    end
  end

  describe '#rejected' do
    let(:link) do
      create(:external_link,
             linkable: authority,
             url: 'https://example.com/spam',
             description: 'Spam link',
             linktype: :other,
             proposer_email: 'spammer@example.com',
             status: :rejected)
    end

    context 'without moderator note' do
      let(:mail) { LinkProposalMailer.rejected(link) }

      it 'sends to the proposer email' do
        expect(mail.to).to eq(['spammer@example.com'])
      end

      it 'has the correct subject' do
        expect(mail.subject).to eq(I18n.t('link_proposal_mailer.rejected.subject'))
      end

      it 'includes link details' do
        expect(mail.body.encoded).to include('https://example.com/spam')
        expect(mail.body.encoded).to include('Spam link')
      end

      it 'does not include moderator note section' do
        expect(mail.body.encoded).not_to include(I18n.t('link_proposal_mailer.rejected.moderator_note'))
      end
    end

    context 'with moderator note' do
      let(:mail) { LinkProposalMailer.rejected(link, 'This link is not relevant to the author') }

      it 'includes the moderator note' do
        expect(mail.body.encoded).to include(I18n.t('link_proposal_mailer.rejected.moderator_note'))
        expect(mail.body.encoded).to include('This link is not relevant to the author')
      end
    end

    it 'includes thank you message' do
      mail = LinkProposalMailer.rejected(link)
      expect(mail.body.encoded).to include(I18n.t('link_proposal_mailer.rejected.thanks'))
    end
  end

  describe '.send_or_queue' do
    let(:link) do
      create(:external_link,
             proposer_email: 'test@example.com',
             status: :approved)
    end

    it 'calls NotificationService with correct parameters' do
      expect(NotificationService).to receive(:call).with(
        mailer_class: LinkProposalMailer,
        mailer_method: :approved,
        recipient_email: 'test@example.com',
        args: [link]
      )

      LinkProposalMailer.send_or_queue(:approved, 'test@example.com', link)
    end

    it 'respects user email preferences through NotificationService' do
      # This test verifies integration with NotificationService
      # The actual email frequency logic is handled by NotificationService
      allow(NotificationService).to receive(:call)

      LinkProposalMailer.send_or_queue(:approved, 'test@example.com', link)

      expect(NotificationService).to have_received(:call)
    end
  end
end
