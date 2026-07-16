# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IngestibleHelper, type: :helper do
  describe '#title_from_prospective_volume_id' do
    it 'returns the explicit title when provided' do
      expect(helper.title_from_prospective_volume_id(nil, 'My Title')).to eq('My Title')
    end

    it 'returns nil when no id and no title are given' do
      expect(helper.title_from_prospective_volume_id(nil, nil)).to be_nil
    end

    it 'returns the collection title when the Collection exists' do
      collection = create(:collection)
      expect(helper.title_from_prospective_volume_id(collection.id.to_s, nil))
        .to eq(collection.title_and_authors)
    end

    it 'returns nil (no crash) when the referenced Collection no longer exists' do
      collection = create(:collection)
      id = collection.id
      collection.destroy
      expect { helper.title_from_prospective_volume_id(id.to_s, nil) }.not_to raise_error
      expect(helper.title_from_prospective_volume_id(id.to_s, nil)).to be_nil
    end

    it 'returns nil (no crash) when the referenced Publication no longer exists' do
      expect { helper.title_from_prospective_volume_id('P999999', nil) }.not_to raise_error
      expect(helper.title_from_prospective_volume_id('P999999', nil)).to be_nil
    end
  end
end
