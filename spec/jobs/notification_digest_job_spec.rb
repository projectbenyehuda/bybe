# frozen_string_literal: true

require 'rails_helper'

describe NotificationDigestJob do
  include ActiveSupport::Testing::TimeHelpers

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

    # by-cnh.3: the once-per-period promise must hold per recipient, not merely because
    # config/recurring.yml happens to fire the job once a day.
    context 'when the job runs more than once' do
      let(:mail_double) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }

      before do
        allow(Notifications).to receive(:notification_digest).and_return(mail_double)
        create(:pending_notification, recipient_email: user.email)
      end

      it 'sends exactly one email for two runs inside the same period' do
        described_class.new.perform('daily')
        create(:pending_notification, recipient_email: user.email)
        described_class.new.perform('daily')

        expect(Notifications).to have_received(:notification_digest).once
      end

      it 'leaves the notifications queued since the suppressed run buffered for next time' do
        described_class.new.perform('daily')
        create(:pending_notification, recipient_email: user.email)

        expect { described_class.new.perform('daily') }.not_to change(PendingNotification, :count)
      end

      it 'sends again once the period has elapsed' do
        described_class.new.perform('daily')
        create(:pending_notification, recipient_email: user.email)
        travel(25.hours) { described_class.new.perform('daily') }

        expect(Notifications).to have_received(:notification_digest).twice
      end

      it 'holds the weekly recipient for a week, not a day' do
        base_user.set_preference(:email_frequency, 'weekly')
        described_class.new.perform('weekly')
        create(:pending_notification, recipient_email: user.email)
        travel(2.days) { described_class.new.perform('weekly') }

        expect(Notifications).to have_received(:notification_digest).once
      end
    end

    # by-cnh.6: the drain and the watermark write must stand or fall together, and a failed
    # delivery must keep its rows for the next run.
    context 'when part of the drain fails' do
      let!(:notification) { create(:pending_notification, recipient_email: user.email) }

      it 'keeps the notifications buffered when the watermark write fails' do
        allow(Notifications).to receive(:notification_digest)
          .and_return(instance_double(ActionMailer::MessageDelivery, deliver_now: true))
        allow(DigestDelivery).to receive(:record!).and_raise(ActiveRecord::RecordNotUnique, 'raced')

        expect { described_class.new.perform('daily') }.not_to change(PendingNotification, :count)
      end

      # Losing the watermark race is the expected outcome of two runs overlapping, not a fault, and
      # must not page anyone.
      it 'logs a lost watermark race at info rather than error' do
        allow(Notifications).to receive(:notification_digest)
          .and_return(instance_double(ActionMailer::MessageDelivery, deliver_now: true))
        allow(DigestDelivery).to receive(:record!).and_raise(ActiveRecord::RecordNotUnique, 'raced')
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)

        described_class.new.perform('daily')

        expect(Rails.logger).to have_received(:info).with(/raced a concurrent run/)
        expect(Rails.logger).not_to have_received(:error)
      end

      it 'keeps the notifications buffered when delivery fails' do
        allow(Notifications).to receive(:notification_digest).and_raise(Net::SMTPServerBusy, 'busy')

        expect { described_class.new.perform('daily') }.not_to change(PendingNotification, :count)
        expect(DigestDelivery.sent_within?(user.email, 23.hours)).to be false
      end

      it 'does not leave the recipient permanently skipped after a failed delivery' do
        allow(Notifications).to receive(:notification_digest).and_raise(Net::SMTPServerBusy, 'busy')
        described_class.new.perform('daily')

        mail_double = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
        allow(Notifications).to receive(:notification_digest).and_return(mail_double)

        expect { described_class.new.perform('daily') }.to change(PendingNotification, :count).by(-1)
      end
    end
  end
end
