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
      let(:entry) { create(:lex_entry, :person) }

      it { is_expected.to redirect_to(lexicon_person_path(entry.lex_item)) }
    end

    context 'when entry is a Publication' do
      let(:entry) { create(:lex_entry, :publication) }

      it { is_expected.to redirect_to(lexicon_publication_path(entry.lex_item)) }
    end
  end
end
