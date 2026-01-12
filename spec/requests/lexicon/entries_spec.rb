# frozen_string_literal: true

require 'rails_helper'

describe '/lexicon/entries' do
  before do
    login_as_lexicon_editor
  end

  describe '#index' do
    subject { get '/lex/entries', params: params }

    let(:params) { {} }

    before do
      create_list(:lex_entry, 2, :person)
      create_list(:lex_entry, 2, :publication)
    end

    it { is_expected.to eq(200) }

    context 'when filtering by status' do
      before do
        create(:lex_entry, :person, status: :draft, title: 'Draft Entry')
        create(:lex_entry, :person, status: :published, title: 'Published Entry')
        create(:lex_entry, :person, status: :verified, title: 'Verified Entry')
      end

      let(:params) { { status: 'draft' } }

      it 'returns only entries with the specified status' do
        expect(subject).to eq(200)
        get '/lex/entries', params: params
        expect(assigns(:lex_entries).map(&:status)).to all(eq('draft'))
        expect(assigns(:lex_entries).pluck(:title)).to include('Draft Entry')
        expect(assigns(:lex_entries).pluck(:title)).not_to include('Published Entry', 'Verified Entry')
      end
    end

    context 'when filtering by title substring' do
      before do
        create(:lex_entry, :person, title: 'Albert Einstein')
        create(:lex_entry, :person, title: 'Marie Curie')
        create(:lex_entry, :person, title: 'Isaac Newton')
      end

      let(:params) { { title: 'ein' } }

      it 'returns only entries with titles matching the substring' do
        expect(subject).to eq(200)
        get '/lex/entries', params: params
        expect(assigns(:lex_entries).pluck(:title)).to include('Albert Einstein')
        expect(assigns(:lex_entries).pluck(:title)).not_to include('Marie Curie', 'Isaac Newton')
      end
    end

    context 'when filtering by both status and title' do
      before do
        create(:lex_entry, :person, status: :draft, title: 'Test Draft Entry')
        create(:lex_entry, :person, status: :published, title: 'Test Published Entry')
        create(:lex_entry, :person, status: :draft, title: 'Another Draft Entry')
      end

      let(:params) { { status: 'draft', title: 'Test' } }

      it 'returns entries matching both filters' do
        expect(subject).to eq(200)
        get '/lex/entries', params: params
        expect(assigns(:lex_entries).count).to eq(1)
        expect(assigns(:lex_entries).first.title).to eq('Test Draft Entry')
      end
    end
  end

  describe '#edit' do
    subject { get "/lex/entries/#{entry.id}/edit" }

    context 'when entry is a Person' do
      let(:entry) { create(:lex_entry, :person) }
      let(:authority) { create(:authority) }

      it { is_expected.to eq(200) }
    end

    context 'when entry is a Publication' do
      let(:entry) { create(:lex_entry, :publication) }

      it { is_expected.to eq(200) }
    end
  end

  describe '#show' do
    subject { get "/lex/entries/#{entry.id}" }

    context 'when entry is a Person' do
      let(:entry) { create(:lex_entry, :person) }
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

  describe 'DELETE /destroy' do
    subject(:call) { delete "/lex/entries/#{entry.id}" }

    context 'when entry is a Person' do
      let!(:entry) { create(:lex_entry, :person) }

      it 'destroys the requested LexEntry and LexPerson' do
        expect { call }.to change(LexPerson, :count).by(-1).and change(LexEntry, :count).by(-1)
        expect(call).to redirect_to lexicon_entries_path
        expect(flash.alert).to eq(I18n.t('lexicon.entries.destroy.success'))
      end
    end

    context 'when entry is a Publication' do
      let!(:entry) { create(:lex_entry, :publication) }

      it 'destroys the requested LexEntry and LexPublication' do
        expect { call }.to change(LexPublication, :count).by(-1).and change(LexEntry, :count).by(-1)
        expect(call).to redirect_to lexicon_entries_path
        expect(flash.alert).to eq(I18n.t('lexicon.entries.destroy.success'))
      end
    end
  end
end
