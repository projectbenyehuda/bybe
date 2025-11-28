# frozen_string_literal: true

require 'rails_helper'

describe TextifyNewPubs do
  describe '#call' do
    subject(:result) { described_class.call(pubs) }

    context 'when pubs is empty' do
      let(:pubs) { {} }

      it { is_expected.to eq('') }
    end

    context 'when pubs contains manifestations' do
      let(:manifestation) { create(:manifestation, status: :published, genre: :poetry) }
      # genre is stored as string in the database
      let(:pubs) { { 'poetry' => [manifestation], latest: manifestation.updated_at } }

      it 'returns HTML string with genre heading' do
        expect(result).to include('<strong>')
      end

      it 'includes link to manifestation' do
        expect(result).to include("/read/#{manifestation.id}")
      end

      it 'includes manifestation title' do
        expect(result).to include(manifestation.expression.title)
      end
    end

    context 'when pubs contains multiple manifestations in same genre' do
      let(:m1) { create(:manifestation, status: :published, genre: :poetry) }
      let(:m2) { create(:manifestation, status: :published, genre: :poetry) }
      let(:pubs) { { 'poetry' => [m1, m2], latest: m2.updated_at } }

      it 'separates manifestations with semicolon' do
        expect(result).to include('; ')
      end
    end

    context 'when pubs contains translations' do
      let(:translation) do
        create(:manifestation, status: :published, genre: :poetry, orig_lang: 'en', language: 'he')
      end
      let(:pubs) { { 'poetry' => [translation], latest: translation.updated_at } }

      it 'includes author name for translations' do
        expect(result).to include(I18n.t(:by))
      end
    end

    context 'when genre key is nil' do
      let(:manifestation) { create(:manifestation, status: :published, genre: :poetry) }
      let(:pubs) { { nil => [manifestation], latest: manifestation.updated_at } }

      it 'shows unknown genre' do
        expect(result).to include(I18n.t(:unknown))
      end
    end
  end
end
