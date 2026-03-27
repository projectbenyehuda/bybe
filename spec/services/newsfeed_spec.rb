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

    context 'when there are recent approved youtube ExternalLinks on Manifestations' do
      let!(:manifestation) { create(:manifestation, orig_lang: 'he') }
      let!(:youtube_link) do
        create(:external_link,
               linkable: manifestation,
               linktype: :youtube,
               status: :approved,
               url: 'https://www.youtube.com/watch?v=abc123',
               description: 'Watch the reading',
               created_at: 1.week.ago)
      end

      it 'includes a youtube news item for the link' do
        youtube_items = result.select(&:youtube?)
        expect(youtube_items.size).to eq(1)

        item = youtube_items.first
        expect(item.url).to eq(youtube_link.url)
        expect(item.title).to eq(manifestation.title_and_authors)
        expect(item.body).to eq('Watch the reading')
      end

      context 'when the youtube link is older than 30 days' do
        let!(:youtube_link) do
          create(:external_link,
                 linkable: manifestation,
                 linktype: :youtube,
                 status: :approved,
                 url: 'https://www.youtube.com/watch?v=abc123',
                 created_at: 31.days.ago)
        end

        it 'does not include the old link' do
          expect(result.select(&:youtube?)).to be_empty
        end
      end

      context 'when the youtube link is not approved' do
        let!(:youtube_link) do
          create(:external_link,
                 linkable: manifestation,
                 linktype: :youtube,
                 status: :submitted,
                 url: 'https://www.youtube.com/watch?v=abc123',
                 created_at: 1.week.ago)
        end

        it 'does not include unapproved links' do
          expect(result.select(&:youtube?)).to be_empty
        end
      end
    end

    context 'when there are recent approved audio ExternalLinks on Manifestations' do
      let!(:manifestation) { create(:manifestation, orig_lang: 'he') }
      let!(:audio_link) do
        create(:external_link,
               linkable: manifestation,
               linktype: :audio,
               status: :approved,
               url: 'https://example.com/audio/poem',
               description: 'Listen to the poem',
               created_at: 3.days.ago)
      end

      it 'includes an audio news item for the link' do
        audio_items = result.select(&:audio?)
        expect(audio_items.size).to eq(1)

        item = audio_items.first
        expect(item.url).to eq(audio_link.url)
        expect(item.title).to eq(manifestation.title_and_authors)
        expect(item.body).to eq('Listen to the poem')
      end
    end

    context 'when a youtube ExternalLink points to a non-YouTube URL' do
      let!(:manifestation) { create(:manifestation, orig_lang: 'he') }
      let!(:video_link) do
        create(:external_link,
               linkable: manifestation,
               linktype: :youtube,
               status: :approved,
               url: 'https://archive.example.org/video/123',
               created_at: 1.week.ago)
      end

      it 'creates an audio item (link only, no iframe) for non-YouTube video URLs' do
        expect(result.select(&:youtube?)).to be_empty
        expect(result.select(&:audio?).size).to eq(1)
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
