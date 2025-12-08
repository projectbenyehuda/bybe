# frozen_string_literal: true

require 'rails_helper'

describe Newsfeed do
  describe '#call' do
    subject(:result) { described_class.call }

    context 'when no new Manifestations exist' do
      it 'returns only persistent news items' do
        expect(result).to be_empty
      end
    end

    context 'when there are several new Manifestations with two different genres' do
      let(:author) { create(:authority) }

      let!(:poetry_manifestation) do
        create(:manifestation, author: author, genre: :poetry, orig_lang: 'he', created_at: 1.week.ago)
      end

      let!(:prose_manifestation) do
        create(:manifestation, author: author, genre: :prose, orig_lang: 'he', created_at: 1.week.ago)
      end

      it 'returns news items with manifestations grouped by genre' do
        expect(result).not_to be_empty

        publication_items = result.select(&:publication?)
        expect(publication_items.size).to eq(1)

        item = publication_items.first
        expect(item.title).to eq(author.name)
        expect(item.body).to include(I18n.t('genre_values.poetry'))
        expect(item.body).to include(I18n.t('genre_values.prose'))
        expect(item.body).to include(poetry_manifestation.expression.title)
        expect(item.body).to include(prose_manifestation.expression.title)
      end
    end
  end
end
