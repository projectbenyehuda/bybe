# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe NotificationDigestJob, type: :job do
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
        expect(Notifications).to receive(:notification_digest)
          .with(user.email, kind_of(ActiveRecord::Relation))
          .and_call_original

        NotificationDigestJob.new.perform('daily')
      end

      it 'deletes sent notifications' do
        allow(Notifications).to receive(:notification_digest).and_return(double(deliver_now: true))

        expect do
          NotificationDigestJob.new.perform('daily')
        end.to change(PendingNotification, :count).by(-2)
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
        expect(Notifications).to receive(:notification_digest)
          .with(user.email, kind_of(ActiveRecord::Relation))
          .and_call_original

        NotificationDigestJob.new.perform('weekly')
      end
    end

    context 'with invalid frequency' do
      it 'logs error and returns' do
        expect(Rails.logger).to receive(:error).with('Invalid frequency: invalid')
        NotificationDigestJob.new.perform('invalid')
      end
    end

    context 'when user has no pending notifications' do
      it 'does not send email' do
        expect(Notifications).not_to receive(:notification_digest)
        NotificationDigestJob.new.perform('daily')
      end
    end
  end

  describe 'enqueuing' do
    it 'enqueues a job' do
      expect do
        NotificationDigestJob.perform_async('daily')
      end.to change(NotificationDigestJob.jobs, :size).by(1)
    end
  end
end
