# frozen_string_literal: true

require 'rails_helper'

# by-cnh.4: NotificationDigestJob only visits users whose current preference is daily or weekly, so
# leaving a throttled frequency used to strand the buffer forever.
describe ResolveBufferedNotifications do
  subject(:call) { described_class.call(recipient_email: user.email, new_frequency: new_frequency) }

  let(:user) { create(:user, email: 'leaver@example.com') }
  let!(:pending) { create_list(:pending_notification, 2, recipient_email: user.email) }

  before { ActionMailer::Base.deliveries.clear }

  context 'when switching to unlimited' do
    let(:new_frequency) { 'unlimited' }

    it 'flushes the buffer' do
      expect { call }.to change(PendingNotification, :count).by(-2)
    end

    it 'delivers what had accumulated' do
      call
      expect(ActionMailer::Base.deliveries.last.to).to eq([user.email])
    end

    it 'ignores the once-per-period watermark, since the user asked to stop being throttled' do
      DigestDelivery.record!(user.email)

      expect { call }.to change(PendingNotification, :count).by(-2)
    end
  end

  context 'when switching to none' do
    let(:new_frequency) { 'none' }

    it 'discards the buffer' do
      expect { call }.to change(PendingNotification, :count).by(-2)
    end

    it 'sends nothing to someone who just asked for silence' do
      call
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  context 'when switching between throttled frequencies' do
    let(:new_frequency) { 'weekly' }

    it 'leaves the buffer alone for the next scheduled digest' do
      expect { call }.not_to change(PendingNotification, :count)
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  context 'when the buffer is empty' do
    let!(:pending) { [] }
    let(:new_frequency) { 'unlimited' }

    it 'sends nothing' do
      call
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  context 'with a blank recipient' do
    let(:new_frequency) { 'none' }

    it 'does nothing' do
      expect { described_class.call(recipient_email: '', new_frequency: 'none') }
        .not_to change(PendingNotification, :count)
    end
  end
end
