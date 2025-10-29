# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PendingNotification, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:recipient_email) }
    it { is_expected.to validate_presence_of(:notification_type) }
    it { is_expected.to validate_presence_of(:notification_data) }
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
end
