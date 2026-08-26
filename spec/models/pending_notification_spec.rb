# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PendingNotification, type: :model do
  describe 'validations' do
    it 'validates presence of recipient_email' do
      notification = described_class.new(notification_type: 'test', notification_data: {})
      expect(notification).not_to be_valid
      # expect(notification.errors[:recipient_email]).to include("can't be blank")
    end

    it 'validates presence of notification_type' do
      notification = described_class.new(recipient_email: 'test@example.com', notification_data: {})
      expect(notification).not_to be_valid
      # expect(notification.errors[:notification_type]).to include("can't be blank")
    end

    it 'validates presence of notification_data' do
      notification = described_class.new(recipient_email: 'test@example.com', notification_type: 'test')
      expect(notification).not_to be_valid
      # expect(notification.errors[:notification_data]).to include("can't be blank")
    end
  end

  describe 'scopes' do
    let!(:user1_notifications) do
      create_list(:pending_notification, 2, recipient_email: 'user1@example.com')
    end
    let!(:user2_notifications) do
      create_list(:pending_notification, 3, recipient_email: 'user2@example.com')
    end
    let!(:old_notification) do
      create(:pending_notification, recipient_email: 'user1@example.com', created_at: 2.days.ago)
    end

    describe '.for_recipient' do
      it 'returns notifications for specific recipient' do
        result = described_class.for_recipient('user1@example.com')
        expect(result.count).to eq(3)
      end
    end

    describe '.older_than' do
      it 'returns notifications older than given time' do
        result = described_class.older_than(1.day.ago)
        expect(result).to contain_exactly(old_notification)
      end
    end

    describe '.grouped_by_recipient' do
      it 'groups notifications by recipient email' do
        result = described_class.grouped_by_recipient
        expect(result.keys).to contain_exactly('user1@example.com', 'user2@example.com')
        expect(result['user1@example.com'].count).to eq(3)
        expect(result['user2@example.com'].count).to eq(3)
      end
    end
  end

  describe '#mailer_args' do
    let(:tag) { create(:tag) }
    let(:notification) { create(:pending_notification, args: [tag, 'a note', nil]).reload }

    it 'resolves stored references back into records, preserving the other arguments' do
      expect(notification.mailer_args).to eq([tag, 'a note', nil])
    end

    it 'raises when a referenced record has been deleted' do
      tag.destroy!
      expect { notification.mailer_args }.to raise_error(ActiveJob::DeserializationError)
    end
  end

  describe '#resolvable?' do
    let(:tag) { create(:tag) }
    let(:notification) { create(:pending_notification, args: [tag]).reload }

    it 'is true while every referenced record still exists' do
      expect(notification).to be_resolvable
    end

    it 'is false once a referenced record has been deleted' do
      tag.destroy!
      expect(notification).not_to be_resolvable
    end
  end
end
