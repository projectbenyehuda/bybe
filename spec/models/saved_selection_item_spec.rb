# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedSelectionItem do
  let(:owner) { create(:user, editor: true) }
  let(:selection) do
    SavedSelection.create!(name: 'Test', user: owner, delete_after: 90.days.from_now.to_date)
  end
  let(:manifestation) { create(:manifestation) }
  let(:collection)    { create(:collection, collection_type: :volume) }

  describe 'item_type validation' do
    it 'is valid with item_type Manifestation' do
      item = described_class.new(saved_selection: selection, item_type: 'Manifestation',
                                 item_id: manifestation.id)
      expect(item).to be_valid
    end

    it 'is valid with item_type Collection' do
      item = described_class.new(saved_selection: selection, item_type: 'Collection',
                                 item_id: collection.id)
      expect(item).to be_valid
    end

    it 'is invalid with an arbitrary item_type' do
      item = described_class.new(saved_selection: selection, item_type: 'Work', item_id: 1)
      expect(item).not_to be_valid
      expect(item.errors[:item_type]).to be_present
    end

    it 'is invalid with a blank item_type' do
      item = described_class.new(saved_selection: selection, item_type: '', item_id: 1)
      expect(item).not_to be_valid
    end
  end
end
