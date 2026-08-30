# frozen_string_literal: true

require 'rails_helper'

# The Authority TOC body and the in-page navbar beside it must agree on which roles have a
# section: every role heading in the TOC needs a navbar entry, and every navbar entry needs a
# TOC anchor to scroll to. The two used to be gated differently (nodes present vs. manifestation
# count > 0), which made them disagree in both directions.
RSpec.describe 'Authority TOC role sections', type: :request do
  subject(:call) { get authority_path(author) }

  let(:author) { create(:authority, :published, uncollected_works_collection: uncollected_collection) }
  let(:uncollected_collection) { create(:collection, :uncollected) }
  let(:original_works_header) { I18n.t('toc_by_role.headers.author', gender_letter: author.gender_letter) }

  context "when the authority's only original works are unpublished ones in others' collections" do
    # Reproduces benyehuda.org/author/2776: the works are visible in the TOC (rendered unlinked)
    # but count as 0, so a count-based gate dropped the role from the navbar only.
    let(:other_authority) { create(:authority) }
    let(:volume) do
      create(:collection, title: 'Somebody Else Volume', collection_type: :volume, authors: [other_authority])
    end

    before do
      Chewy.strategy(:atomic) do
        manifestation = create(:manifestation, author: author, status: :nonpd, title: 'An Unpublished Work')
        create(:collection_item, collection: volume, item: manifestation)
      end
      call
    end

    it 'renders the original-works section in the TOC body' do
      expect(response.body).to include(original_works_header)
      expect(response.body).to include('id="works-author-work-level"')
    end

    it 'renders the original-works group in the navbar too' do
      navbar = navbar_fragment(response.body)
      expect(navbar).to include(original_works_header)
      expect(navbar).to include('data-scroll-target="#works-author-work-level"')
    end

    it 'shows no count badge for the section, since nothing in it is published' do
      expect(response.body).not_to include('<span class="count-badge"> (0)</span>')
    end
  end

  context 'when the authority has only uncollected works in a role' do
    # Reproduces benyehuda.org/author/26: the TOC body rendered nothing at all, while the navbar
    # still offered an 'uncollected works' entry pointing at an anchor that did not exist.
    before do
      Chewy.strategy(:atomic) do
        manifestation = create(:manifestation, author: author, status: :published, title: 'A Lone Work')
        create(:collection_item, collection: uncollected_collection, item: manifestation)
      end
      call
    end

    it 'renders the uncollected section in the TOC body' do
      expect(response.body).to include(original_works_header)
      expect(response.body).to include('id="works-author-uncollected"')
      expect(response.body).to include('A Lone Work')
    end

    it 'points the navbar at that section' do
      navbar = navbar_fragment(response.body)
      expect(navbar).to include(original_works_header)
      expect(navbar).to include('data-scroll-target="#works-author-uncollected"')
    end
  end

  context 'when a role has published works' do
    let(:volume) { create(:collection, title: 'Own Volume', collection_type: :volume, authors: [author]) }

    before do
      Chewy.strategy(:atomic) do
        manifestation = create(:manifestation, author: author, status: :published, title: 'A Published Work')
        create(:collection_item, collection: volume, item: manifestation)
      end
      call
    end

    it 'still shows the section with its count badge' do
      expect(response.body).to include(original_works_header)
      expect(response.body).to include('id="works-author-collection-level"')
      expect(response.body).to include('<span class="count-badge"> (1)</span>')
    end
  end
end
