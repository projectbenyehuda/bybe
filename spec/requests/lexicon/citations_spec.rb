# frozen_string_literal: true

require 'rails_helper'

describe '/lexicon/citations' do
  let(:entry) { create(:lex_entry, :person) }
  let(:person) { entry.lex_item }

  let!(:citations) { create_list(:lex_citation, 3, item: person) }

  let(:citation) { citations.first }

  describe 'GET /lexicon/people/:ID/citations' do
    subject(:call) { get "/lex/entries/#{entry.id}/citations" }

    it { is_expected.to eq(200) }
  end

  describe 'GET /lexicon/entries/:ID/citations/new' do
    subject(:call) { get "/lex/entries/#{entry.id}/citations/new" }

    it { is_expected.to eq(200) }
  end

  describe 'POST /lex/entries/:ID/citations' do
    subject(:call) { post "/lex/entries/#{entry.id}/citations", params: { lex_citation: citation_params }, xhr: true }

    context 'when valid params' do
      let(:citation_params) { attributes_for(:lex_citation) }

      it 'creates new record' do
        expect { call }.to change { entry.lex_item.citations.count }.by(1)
        expect(call).to eq(200)

        citation = LexCitation.last
        expect(citation).to have_attributes(citation_params)
      end
    end

    context 'when invalid params' do
      let(:citation_params) { attributes_for(:lex_citation, title: '') }

      it 're-renders edit form' do
        expect { call }.not_to(change { entry.lex_item.citations.count })
        expect(call).to eq(422)
        expect(call).to render_template(:new)
      end
    end
  end

  describe 'GET /lexicon/citations/:id/edit' do
    subject(:call) { get "/lex/citations/#{citation.id}/edit" }

    it { is_expected.to eq(200) }
  end

  describe 'PATCH /lex/citations/:id' do
    subject(:call) { patch "/lex/citations/#{citation.id}", params: { lex_citation: citation_params }, xhr: true }

    context 'when valid params' do
      let(:citation_params) { attributes_for(:lex_citation) }

      it 'updates record' do
        expect(call).to eq(200)
        expect(citation.reload).to have_attributes(citation_params)
      end
    end

    context 'when invalid params' do
      let(:citation_params) { attributes_for(:lex_citation, title: '') }

      it 're-renders edit form' do
        expect(call).to eq(422)
        expect(call).to render_template(:edit)
      end
    end

    context 'when'
  end

  describe 'DELETE /lex/citations/:id' do
    subject(:call) { delete "/lex/citations/#{citation.id}", xhr: true }

    it 'removes record' do
      expect { call }.to change { entry.lex_item.citations.count }.by(-1)
      expect(call).to eq(200)
    end
  end
end
