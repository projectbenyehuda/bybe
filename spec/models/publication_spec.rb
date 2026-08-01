# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Publication, type: :model do
  describe 'reporting a publication as missing from its lexicon entry' do
    let(:publication) { create(:publication) }

    it 'is not reported by default' do
      expect(publication).not_to be_reported_missing_from_lexicon
    end

    it 'is reported once flagged, and records the reporting user' do
      user = create(:user)

      publication.mark_reported_missing_from_lexicon!(user)

      expect(publication.reload).to be_reported_missing_from_lexicon
      expect(ListItem.find_by(listkey: described_class::LEX_REPORTED_MISSING_LISTKEY, item: publication).user)
        .to eq(user)
    end

    it 'is idempotent' do
      publication.mark_reported_missing_from_lexicon!
      publication.mark_reported_missing_from_lexicon!

      expect(ListItem.where(listkey: described_class::LEX_REPORTED_MISSING_LISTKEY, item: publication).count).to eq(1)
    end

    it 'does not flag other publications' do
      other = create(:publication)
      publication.mark_reported_missing_from_lexicon!

      expect(other.reload).not_to be_reported_missing_from_lexicon
    end
  end

  describe '.update_publications_that_may_be_done_list' do
    subject(:run) { described_class.update_publications_that_may_be_done_list }

    before { allow($stdout).to receive(:write) }

    # Use a known prefix so we can craft matching/non-matching titles reliably.
    let(:shared_prefix) { 'אבגדהוזחטי' } # 10 Hebrew chars → first 11 chars are deterministic

    let(:authority) { create(:authority) }

    let!(:matching_pub) do
      create(:publication, status: :todo, authority: authority, title: "#{shared_prefix} additional words")
    end

    let!(:non_matching_pub) do
      create(:publication, status: :todo, authority: authority, title: 'fully different title here')
    end

    let!(:_matching_manifestation) do
      create(:manifestation, title: "#{shared_prefix} different suffix", author: authority)
    end

    context 'when the author has a work whose title prefix matches the publication title prefix' do
      it 'adds the matching publication to the pubs_maybe_done list' do
        expect { run }.to change {
          ListItem.where(listkey: 'pubs_maybe_done', item: matching_pub).count
        }.from(0).to(1)
      end
    end

    context 'when the author has works but none with a matching title prefix' do
      it 'does not add the non-matching publication to the list' do
        expect { run }.not_to(change do
          ListItem.where(listkey: 'pubs_maybe_done', item: non_matching_pub).count
        end)
      end
    end

    context 'when the author has no works at all' do
      let(:authority_without_works) { create(:authority) }
      let!(:orphan_pub) do
        create(:publication, status: :todo, authority: authority_without_works, title: shared_prefix)
      end

      it 'does not add the publication to the list' do
        expect { run }.not_to(change do
          ListItem.where(listkey: 'pubs_maybe_done', item: orphan_pub).count
        end)
      end
    end

    context 'when the publication is already uploaded' do
      let!(:uploaded_pub) do
        create(:publication, status: :uploaded, authority: authority, title: "#{shared_prefix} suffix")
      end

      it 'skips uploaded publications' do
        expect { run }.not_to(change do
          ListItem.where(listkey: 'pubs_maybe_done', item: uploaded_pub).count
        end)
      end
    end

    context 'when the publication is already in the pubs_maybe_done list' do
      let!(:already_listed_pub) do
        create(:publication, :pubs_maybe_done, status: :todo, authority: authority,
                                               title: "#{shared_prefix} suffix")
      end

      it 'skips already-listed publications' do
        expect { run }.not_to(change do
          ListItem.where(listkey: 'pubs_maybe_done', item: already_listed_pub).count
        end)
      end
    end
  end
end
