# frozen_string_literal: true

require 'rails_helper'

describe TextifyNewPubs do
  describe '#call' do
    subject(:result) { described_class.call(manifestations) }

    context 'when manifestations is empty' do
      let(:manifestations) { [] }

      it { is_expected.to eq('') }
    end

    context 'when there are several manifestations' do
      let(:poetry1) { create(:manifestation, genre: :poetry, orig_lang: 'he', language: 'he') }
      let(:poetry2) { create(:manifestation, genre: :poetry, orig_lang: 'he', language: 'he') }
      let(:prose1) { create(:manifestation, genre: :prose, orig_lang: 'he', language: 'he') }
      let(:translation) { create(:manifestation, genre: :prose, orig_lang: 'en', language: 'he') }
      let(:manifestations) { [poetry1, poetry2, prose1, translation] }
      let(:tr_author) { translation.expression.work.authors.first }

      let(:expected_result) do
        <<~HTML.squish.gsub('<br /> ', '<br />')
          <strong>#{I18n.t('genre_values.poetry')}:</strong>
           <a href="/read/#{poetry1.id}">#{poetry1.expression.title}</a>;
           <a href="/read/#{poetry2.id}">#{poetry2.expression.title}</a><br />
          <strong>#{I18n.t('genre_values.prose')}:</strong>
           <a href="/read/#{prose1.id}">#{prose1.expression.title}</a>;
           <a href="/read/#{translation.id}">#{translation.expression.title} #{I18n.t(:by)} #{tr_author.name}</a><br />
        HTML
      end

      it 'returns HTML with genre headings, links, and author for translation' do
        expect(result).to eq(expected_result)
      end
    end
  end
end
