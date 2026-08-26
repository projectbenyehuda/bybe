# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notifications, type: :mailer do
  describe 'handling deleted users' do
    let(:user) { create(:user) }

    describe '#tag_approved' do
      context 'when creator exists' do
        let(:tag) { create(:tag, creator: user) }
        let(:mail) { described_class.tag_approved(tag) }

        it 'sends email to creator' do
          expect(mail.to).to eq([user.email])
        end

        it 'includes creator name in body' do
          expect(mail.body.encoded).to include(user.name)
        end
      end

      context 'when creator is nil (deleted user)' do
        let(:tag) { create(:tag, creator: user) }

        before do
          # Simulate user deletion by setting creator_id to nil
          tag.update_column(:created_by, nil)
        end

        it 'does not send email' do
          mail = described_class.tag_approved(tag)
          expect(mail.message).to be_a(ActionMailer::Base::NullMail)
        end

        it 'does not crash' do
          expect { described_class.tag_approved(tag) }.not_to raise_error
        end
      end
    end

    describe '#tag_rejected' do
      context 'when creator exists' do
        let(:tag) { create(:tag, creator: user) }
        let(:mail) { described_class.tag_rejected(tag, 'Not relevant') }

        it 'sends email to creator' do
          expect(mail.to).to eq([user.email])
        end

        it 'includes creator name in body' do
          expect(mail.body.encoded).to include(user.name)
        end
      end

      context 'when creator is nil (deleted user)' do
        let(:tag) { create(:tag, creator: user) }

        before do
          tag.update_column(:created_by, nil)
        end

        it 'does not send email' do
          mail = described_class.tag_rejected(tag, 'Not relevant')
          expect(mail.message).to be_a(ActionMailer::Base::NullMail)
        end

        it 'does not crash' do
          expect { described_class.tag_rejected(tag, 'Not relevant') }.not_to raise_error
        end
      end
    end

    describe '#tagging_approved' do
      context 'when suggester exists' do
        let(:tagging) { create(:tagging, suggester: user) }
        let(:mail) { described_class.tagging_approved(tagging) }

        it 'sends email to suggester' do
          expect(mail.to).to eq([user.email])
        end

        it 'includes suggester name in body' do
          expect(mail.body.encoded).to include(user.name)
        end
      end

      context 'when suggester is nil (deleted user)' do
        let(:tagging) { create(:tagging, suggester: user) }

        before do
          tagging.update_column(:suggested_by, nil)
        end

        it 'does not send email' do
          mail = described_class.tagging_approved(tagging)
          expect(mail.message).to be_a(ActionMailer::Base::NullMail)
        end

        it 'does not crash' do
          expect { described_class.tagging_approved(tagging) }.not_to raise_error
        end
      end
    end

    describe '#tagging_rejected' do
      context 'when suggester exists' do
        let(:tagging) { create(:tagging, suggester: user) }
        let(:mail) { described_class.tagging_rejected(tagging, 'Not relevant') }

        it 'sends email to suggester' do
          expect(mail.to).to eq([user.email])
        end

        it 'includes suggester name in body' do
          expect(mail.body.encoded).to include(user.name)
        end
      end

      context 'when suggester is nil (deleted user)' do
        let(:tagging) { create(:tagging, suggester: user) }

        before do
          tagging.update_column(:suggested_by, nil)
        end

        it 'does not send email' do
          mail = described_class.tagging_rejected(tagging, 'Not relevant')
          expect(mail.message).to be_a(ActionMailer::Base::NullMail)
        end

        it 'does not crash' do
          expect { described_class.tagging_rejected(tagging, 'Not relevant') }.not_to raise_error
        end
      end
    end
  end

  # by-cnh.7: the digest used to render every buffered row in full, so a repetitive or long-
  # accumulated buffer produced a wall of near-identical blocks, or an email too big to deliver.
  describe '#notification_digest' do
    subject(:mail) { described_class.notification_digest(user.email, notifications) }

    let(:user) { create(:user) }
    # Named explicitly so the body assertions below search for a string that is obviously this
    # tag; the names only have to be distinguishable from one another in the rendered body.
    let(:tag) { create(:tag, name: 'digest-tag-alpha', creator: user) }

    context 'with the same notification buffered several times' do
      let(:notifications) { create_list(:pending_notification, 3, recipient_email: user.email, args: [tag]) }

      it 'renders the notification once' do
        expect(mail.body.encoded.scan(tag.name).size).to eq(1)
      end

      it 'says how many times it arrived' do
        expect(mail.body.encoded).to include(ERB::Util.html_escape(I18n.t(:notification_repeated, count: 3)))
      end
    end

    context 'with distinct notifications of the same type' do
      let(:other_tag) { create(:tag, name: 'digest-tag-beta', creator: user) }
      let(:notifications) do
        [create(:pending_notification, recipient_email: user.email, args: [tag]),
         create(:pending_notification, recipient_email: user.email, args: [other_tag])]
      end

      it 'renders both, since they are two different things to report' do
        expect(mail.body.encoded).to include(tag.name).and include(other_tag.name)
      end

      it 'does not claim either one repeated' do
        expect(mail.body.encoded).not_to include(ERB::Util.html_escape(I18n.t(:notification_repeated, count: 2)))
      end
    end

    context 'with more distinct notifications than the cap' do
      let(:notifications) do
        # Zero-padded so that no name is a substring of another ('...-01' vs '...-010'), which the
        # substring search below would otherwise miscount.
        Array.new(Notifications::MAX_DIGEST_ITEMS + 3) do |i|
          capped_tag = create(:tag, name: format('digest-capped-tag-%02d', i), creator: user)
          create(:pending_notification, recipient_email: user.email, args: [capped_tag])
        end
      end

      it 'renders only up to the cap' do
        rendered = notifications.first(Notifications::MAX_DIGEST_ITEMS).map { |n| n.mailer_args.first.name }
        expect(rendered.count { |name| mail.body.encoded.include?(name) }).to eq(Notifications::MAX_DIGEST_ITEMS)
      end

      it 'summarises the remainder as a count' do
        expect(mail.body.encoded).to include(ERB::Util.html_escape(I18n.t(:notification_digest_omitted, count: 3)))
      end
    end

    context 'with fewer notifications than the cap' do
      let(:notifications) { [create(:pending_notification, recipient_email: user.email, args: [tag])] }

      it 'says nothing about omitted notifications' do
        expect(mail.body.encoded).not_to include(ERB::Util.html_escape(I18n.t(:notification_digest_omitted, count: 1)))
      end
    end
  end
end
