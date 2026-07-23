# frozen_string_literal: true

require 'rails_helper'

describe PurgeExpiredSavedSelections do
  subject(:call) do
    perform_enqueued_jobs do
      described_class.perform_later
    end
  end

  let!(:saved_selections_to_purge) do
    create_list(:saved_selection, 3, delete_after: Time.zone.today - 1.hour, items_count: 2)
  end
  let!(:saved_selections_to_keep) { create(:saved_selection, delete_after: 1.hour.after, items_count: 3) }

  it 'deletes expired saved selections and keeps not yet expired' do
    expect { call }.to change(SavedSelection, :count).by(-3).and change(SavedSelectionItem, :count).by(-6)
    expect { saved_selections_to_keep.reload }.not_to raise_exception
    expect(saved_selections_to_keep.saved_selection_items.count).to eq(3)
  end
end
