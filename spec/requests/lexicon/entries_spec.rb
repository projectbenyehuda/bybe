# frozen_string_literal: true

require 'rails_helper'

describe '/lexicon/entries' do
  describe '#index' do
    subject { get '/lex/entries' }

    before do
      create_list(:lex_entry, 2, :person)
      create_list(:lex_entry, 2, :publication)
    end

    it { is_expected.to eq(200) }
  end

  describe '#show' do
    subject { get "/lex/entries/#{entry.id}" }

    context 'when entry is a Person' do
      let(:entry) { create(:lex_entry, :person, status: :migrated) }
      let(:authority) { create(:authority) }

      it { is_expected.to eq(200) }

      context 'when entry has authority' do
        before do
          entry.lex_item.update!(authority_id: authority.id)
        end

        it { is_expected.to eq(200) }
      end
    end

    context 'when entry is a Publication' do
      let(:entry) { create(:lex_entry, :publication) }

      it { is_expected.to eq(200) }
    end
  end
end
