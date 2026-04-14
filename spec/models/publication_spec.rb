# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Publication, type: :model do
  describe '.update_publications_that_may_be_done_list' do
    subject(:run) { described_class.update_publications_that_may_be_done_list }

    def pub_title_for_comparison(str)
      ret = if str['/'].nil?
              str[0..[10, str.length].min]
            else
              str[0..[10, str.index('/') - 1].min]
            end
      ret.strip
    end

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
