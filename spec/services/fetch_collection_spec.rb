# frozen_string_literal: true

require 'rails_helper'

describe FetchCollection do
  subject(:result) { described_class.call(collection) }

  let(:sub_collection_1) { create(:collection, manifestations: create_list(:manifestation, 2)) }
  let(:sub_collection_2) { create(:collection, manifestations: create_list(:manifestation, 3)) }

  let(:collection) { create(:collection, included_collections: [sub_collection_1, sub_collection_2]) }
  let!(:parent_collection) { create(:collection, included_collections: [collection]) }

  it 'fetches all manifestations and collections' do
    expect(result.all_manifestations.size).to eq(5)
  end
end
