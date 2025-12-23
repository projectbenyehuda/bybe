# frozen_string_literal: true

require 'rails_helper'

describe '/lexicon/links' do
  let(:person) { create(:lex_entry, :person).lex_item }

  let!(:links) { create_list(:lex_link, 3, item: person) }

  let(:link) { links.first }

  describe 'GET /lexicon/people/:ID/links' do
    subject(:call) { get "/lex/people/#{person.id}/links" }

    it { is_expected.to eq(200) }
  end

  describe 'GET /lexicon/people/:ID/links/new' do
    subject(:call) { get "/lex/people/#{person.id}/links/new" }

    it { is_expected.to eq(200) }
  end

  describe 'POST /lex/people/:ID/links' do
    subject(:call) { post "/lex/people/#{person.id}/links", params: { lex_link: link_params }, xhr: true }

    context 'when valid params' do
      let(:link_params) { attributes_for(:lex_link).except(:item) }

      it 'creates new record' do
        expect { call }.to change { person.links.count }.by(1)
        expect(call).to eq(200)

        created_link = LexLink.last
        expect(created_link).to have_attributes(link_params)
      end
    end

    context 'when invalid params' do
      let(:link_params) { attributes_for(:lex_link, url: '') }

      it 're-renders new form' do
        expect { call }.not_to(change { person.links.count })
        expect(call).to eq(422)
        expect(call).to render_template(:new)
      end
    end
  end

  describe 'GET /lexicon/links/:id/edit' do
    subject(:call) { get "/lex/links/#{link.id}/edit" }

    it { is_expected.to eq(200) }
  end

  describe 'PATCH /lex/links/:id' do
    subject(:call) { patch "/lex/links/#{link.id}", params: { lex_link: link_params }, xhr: true }

    context 'when valid params' do
      let(:link_params) { attributes_for(:lex_link) }

      it 'updates record' do
        expect(call).to eq(200)
        expect(link.reload).to have_attributes(link_params.except(:item))
      end
    end

    context 'when invalid params' do
      let(:link_params) { attributes_for(:lex_link, url: '') }

      it 're-renders edit form' do
        expect(call).to eq(422)
        expect(call).to render_template(:edit)
      end
    end
  end

  describe 'DELETE /lex/links/:id' do
    subject(:call) { delete "/lex/links/#{link.id}", xhr: true }

    it 'removes record' do
      expect { call }.to change { person.links.count }.by(-1)
      expect(call).to eq(200)
    end
  end
end
