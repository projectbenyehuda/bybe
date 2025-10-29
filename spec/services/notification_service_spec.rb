# frozen_string_literal: true

require 'rails_helper'

describe NotificationService do
  let(:user) { create(:user, email: 'test@example.com') }
  let!(:base_user) { create(:base_user, user: user) }
  let(:mailer_class) { Notifications }
  let(:mailer_method) { :tag_approved }
  let(:tag) { double('Tag', creator: user) }
  let(:args) { [tag] }

  describe '#call' do
    context 'when user has unlimited email frequency' do
      before do
        base_user.set_preference(:email_frequency, 'unlimited')
      end

      it 'sends email immediately' do
        expect(mailer_class).to receive(:tag_approved).with(tag).and_call_original
        described_class.call(
          mailer_class: mailer_class,
          mailer_method: mailer_method,
          recipient_email: user.email,
          args: args
        )
      end
    end

    context 'when user has daily email frequency' do
      before do
        base_user.set_preference(:email_frequency, 'daily')
      end

      it 'queues notification instead of sending' do
        expect do
          described_class.call(
            mailer_class: mailer_class,
            mailer_method: mailer_method,
            recipient_email: user.email,
            args: args
          )
        end.to change(PendingNotification, :count).by(1)
      end

      it 'stores notification data correctly' do
        described_class.call(
          mailer_class: mailer_class,
          mailer_method: mailer_method,
          recipient_email: user.email,
          args: args
        )

        notification = PendingNotification.last
        expect(notification.recipient_email).to eq(user.email)
        expect(notification.notification_type).to eq('Notifications#tag_approved')
      end
    end

    context 'when user has weekly email frequency' do
      before do
        base_user.set_preference(:email_frequency, 'weekly')
      end

      it 'queues notification instead of sending' do
        expect do
          described_class.call(
            mailer_class: mailer_class,
            mailer_method: mailer_method,
            recipient_email: user.email,
            args: args
          )
        end.to change(PendingNotification, :count).by(1)
      end
    end

    context 'when user has no emails preference' do
      before do
        base_user.set_preference(:email_frequency, 'none')
      end

      it 'does not send or queue notification' do
        expect(mailer_class).not_to receive(:tag_approved)
        expect do
          described_class.call(
            mailer_class: mailer_class,
            mailer_method: mailer_method,
            recipient_email: user.email,
            args: args
          )
        end.not_to change(PendingNotification, :count)
      end
    end

    context 'when recipient is not a registered user' do
      let(:non_user_email) { 'nonuser@example.com' }

      it 'sends email immediately (default unlimited)' do
        expect(mailer_class).to receive(:tag_approved).with(tag).and_call_original
        described_class.call(
          mailer_class: mailer_class,
          mailer_method: mailer_method,
          recipient_email: non_user_email,
          args: args
        )
      end
    end
  end
end
