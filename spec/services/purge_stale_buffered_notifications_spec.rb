# frozen_string_literal: true

require 'rails_helper'

describe PurgeStaleBufferedNotifications do
  subject(:call) { described_class.call }

  let!(:stale) { create(:pending_notification, recipient_email: 'gone@example.com', created_at: 3.weeks.ago) }
  let!(:fresh) { create(:pending_notification, recipient_email: 'here@example.com', created_at: 2.days.ago) }

  # Rows keyed on an address whose account no longer exists are exactly what nothing else visits.
  it 'purges rows past the ceiling' do
    expect { call }.to change(PendingNotification, :count).by(-1)
    expect(PendingNotification.exists?(stale.id)).to be false
  end

  it 'leaves rows a live schedule would still deliver' do
    call
    expect(PendingNotification.exists?(fresh.id)).to be true
  end

  it 'reports how many it purged' do
    expect(call).to eq(1)
  end
end
