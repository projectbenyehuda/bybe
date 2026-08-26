# frozen_string_literal: true

require 'rails_helper'

describe NotificationDigestJob do
  let(:user) { create(:user, email: 'test@example.com') }
  let!(:base_user) { create(:base_user, user: user) }

  before do
    base_user.set_preference(:email_frequency, 'daily')
  end

  describe '#perform' do
    context 'with daily frequency' do
      let!(:old_notification) do
        create(:pending_notification,
               recipient_email: user.email,
               created_at: 2.days.ago)
      end
      let!(:new_notification) do
        create(:pending_notification,
               recipient_email: user.email,
               created_at: 1.hour.ago)
      end

      it 'sends digest email for users with pending notifications' do
        mail_double = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
        expect(Notifications).to receive(:notification_digest)
          .with(user.email, kind_of(Array))
          .and_return(mail_double)
        expect(mail_double).to receive(:deliver_now)

        described_class.new.perform('daily')
      end

      # Regression test: the job used to select only rows older than a full period, so a
      # notification queued since the previous run waited for the run after it -- up to ~48h for
      # daily, against a UI that promises at most one day.
      it 'drains notifications queued since the previous run, not just old ones' do
        allow(Notifications).to receive(:notification_digest)
          .and_return(instance_double(ActionMailer::MessageDelivery, deliver_now: true))

        expect do
          described_class.new.perform('daily')
        end.to change(PendingNotification, :count).by(-2)
      end

      it 'includes every pending notification in the digest' do
        allow(Notifications).to receive(:notification_digest)
          .and_return(instance_double(ActionMailer::MessageDelivery, deliver_now: true))

        described_class.new.perform('daily')

        expect(Notifications).to have_received(:notification_digest)
          .with(user.email, contain_exactly(old_notification, new_notification))
      end
    end

    context 'with weekly frequency' do
      before do
        base_user.set_preference(:email_frequency, 'weekly')
      end

      let!(:old_notification) do
        create(:pending_notification,
               recipient_email: user.email,
               created_at: 2.weeks.ago)
      end

      it 'sends digest email for users with weekly preference' do
        mail_double = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
        expect(Notifications).to receive(:notification_digest)
          .with(user.email, kind_of(Array))
          .and_return(mail_double)
        expect(mail_double).to receive(:deliver_now)

        described_class.new.perform('weekly')
      end
    end

    context 'with invalid frequency' do
      it 'logs error and returns' do
        expect(Rails.logger).to receive(:error).with('Invalid frequency: invalid')
        described_class.new.perform('invalid')
      end
    end

    context 'when user has no pending notifications' do
      it 'does not send email' do
        expect(Notifications).not_to receive(:notification_digest)
        described_class.new.perform('daily')
      end
    end

    # End-to-end through the real mailer and view: this is what actually lands in the recipient's
    # inbox, and what used to be a page of `notification_render_error` placeholders.
    context 'with a real notification carrying a model argument' do
      let(:tag) { create(:tag, creator: user) }

      before do
        ActionMailer::Base.deliveries.clear
        Notifications.send_or_queue(:tag_approved, user.email, tag)
      end

      it 'renders the notification content rather than an error placeholder' do
        described_class.new.perform('daily')

        digest = ActionMailer::Base.deliveries.last
        expect(digest.to).to eq([user.email])
        expect(digest.body.encoded).to include(tag.name)
        expect(digest.body.encoded).not_to include(I18n.t(:notification_render_error))
      end
    end

    # by-cnh.5: a dangling reference must not cost the recipient their other notifications, nor
    # survive to fail again on the next run.
    context 'when a referenced record has been deleted' do
      let(:doomed_tag) { create(:tag, creator: user) }
      let(:live_tag) { create(:tag, creator: user) }

      before do
        ActionMailer::Base.deliveries.clear
        Notifications.send_or_queue(:tag_approved, user.email, doomed_tag)
        Notifications.send_or_queue(:tag_approved, user.email, live_tag)
        doomed_tag.destroy!
      end

      it 'still delivers the remaining notifications' do
        described_class.new.perform('daily')

        digest = ActionMailer::Base.deliveries.last
        expect(digest.body.encoded).to include(live_tag.name)
      end

      it 'drops the unresolvable notification instead of retrying it forever' do
        expect do
          described_class.new.perform('daily')
        end.to change(PendingNotification, :count).by(-2)
      end
    end
  end
end
