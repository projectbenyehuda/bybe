# frozen_string_literal: true

require 'rails_helper'

describe TextifyNewPubs do
  describe '#call' do
    subject(:result) { described_class.call(manifestations) }

    context 'when manifestations is empty' do
      let(:manifestations) { [] }

      it { is_expected.to eq('') }
    end

    context 'when manifestations is nil' do
      let(:manifestations) { nil }

      it { is_expected.to eq('') }
    end

    context 'when manifestations contains items' do
      let(:manifestation) { create(:manifestation, status: :published, genre: :poetry) }
      let(:manifestations) { [manifestation] }

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

    context 'when manifestations contains multiple items in same genre' do
      let(:m1) { create(:manifestation, status: :published, genre: :poetry) }
      let(:m2) { create(:manifestation, status: :published, genre: :poetry) }
      let(:manifestations) { [m1, m2] }

      it 'separates manifestations with semicolon' do
        expect(result).to include('; ')
      end

      it 'groups them under same genre heading' do
        expect(result.scan('<strong>').count).to eq(1)
      end
    end

    context 'when manifestations contains items from different genres' do
      let(:m1) { create(:manifestation, status: :published, genre: :poetry) }
      let(:m2) { create(:manifestation, status: :published, genre: :prose) }
      let(:manifestations) { [m1, m2] }

      it 'creates separate genre headings' do
        expect(result.scan('<strong>').count).to eq(2)
      end
    end

    context 'when manifestations contains translations' do
      let(:translation) do
        create(:manifestation, status: :published, genre: :poetry, orig_lang: 'en', language: 'he')
      end
      let(:manifestations) { [translation] }

      it 'includes author name for translations' do
        expect(result).to include(I18n.t(:by))
      end
    end
  end
end
