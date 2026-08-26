# frozen_string_literal: true

require 'rails_helper'

describe DigestDelivery do
  describe '.sent_within?' do
    before { create(:digest_delivery, recipient_email: 'a@example.com', last_digest_sent_at: 10.hours.ago) }

    it 'is true when the last digest falls inside the interval' do
      expect(described_class.sent_within?('a@example.com', 23.hours)).to be true
    end

    it 'is false when the last digest is older than the interval' do
      expect(described_class.sent_within?('a@example.com', 5.hours)).to be false
    end

    it 'is false for a recipient that was never sent a digest' do
      expect(described_class.sent_within?('b@example.com', 23.hours)).to be false
    end
  end

  describe '.record!' do
    it 'creates a watermark for a new recipient' do
      expect { described_class.record!('a@example.com') }.to change(described_class, :count).by(1)
    end

    it 'moves an existing recipient watermark forward rather than adding a row' do
      described_class.record!('a@example.com', 2.days.ago)

      expect { described_class.record!('a@example.com') }.not_to change(described_class, :count)
      expect(described_class.sent_within?('a@example.com', 1.hour)).to be true
    end
  end
end
