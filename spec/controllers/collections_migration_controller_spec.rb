# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CollectionsMigrationController do
  let(:authority) { create(:authority) }

  before do
    allow(controller).to receive(:require_editor)
  end

  describe 'POST #create_collection' do
    context 'when creating a series collection' do
      it 'does not set publisher_line and pub_year' do
        expect do
          post :create_collection, params: {
            authority: authority.id,
            title: 'Test Series',
            collection_type: 'series',
            role: 'author',
            guessed_publisher: 'Some Publisher',
            guessed_year: '2020'
          }
        end.to change(Collection, :count).by(1)

        collection = assigns(:collection)
        expect(collection.collection_type).to eq 'series'
        expect(collection.publisher_line).to be_nil
        expect(collection.pub_year).to be_nil
      end
    end

    context 'when creating a volume collection' do
      it 'sets publisher_line and pub_year' do
        expect do
          post :create_collection, params: {
            authority: authority.id,
            title: 'Test Volume',
            collection_type: 'volume',
            role: 'author',
            guessed_publisher: 'Some Publisher',
            guessed_year: '2020'
          }
        end.to change(Collection, :count).by(1)

        collection = assigns(:collection)
        expect(collection.collection_type).to eq 'volume'
        expect(collection.publisher_line).to eq 'Some Publisher'
        expect(collection.pub_year).to eq '2020'
      end
    end
  end
end
