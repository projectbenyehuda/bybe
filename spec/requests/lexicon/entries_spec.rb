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
end
