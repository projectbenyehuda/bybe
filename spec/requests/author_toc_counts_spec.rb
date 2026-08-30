# frozen_string_literal: true

require 'rails_helper'

# The author page states two figures in its metadata card -- 'titles in the project' and 'works in
# the project' -- and then repeats them as count badges over the TOC and the in-page navbar beside
# it. Reproduces benyehuda.org/author/1024, where the card said 4 titles / 36 works while the TOC
# showed 2 volume cards and a badge of 38.
RSpec.describe 'Authority TOC counts', type: :request do
  subject(:call) { get authority_path(author) }

  let(:author) { create(:authority, :published, uncollected_works_collection: uncollected_collection) }
  let(:uncollected_collection) { create(:collection, :uncollected) }
  let(:other_authority) { create(:authority) }

  # A multi-volume title, structured the way author/1024's is: one volume card holding two `series`
  # sub-collections, with the author credited on the sub-collections as well as on the volume.
  let(:first_section) { create(:collection, collection_type: :series, title: 'First Section', authors: [author]) }
  let(:second_section) { create(:collection, collection_type: :series, title: 'Second Section', authors: [author]) }
  let(:volume) do
    create(
      :collection,
      collection_type: :volume,
      title: 'Collected Studies',
      authors: [author],
      included_collections: [first_section, second_section]
    )
  end

  before do
    Chewy.strategy(:atomic) do
      volume # force creation of the whole hierarchy
      create_list(:manifestation, 2, author: author, collections: [first_section])
      create(:manifestation, author: author, collections: [second_section])
      # Somebody else's preface, sitting in this author's volume
      create(:manifestation, author: other_authority, title: 'A Foreign Preface', collections: [second_section])
    end
    Rails.cache.clear
    call
  end

  it 'counts only the volume as a title, not the series sections nested inside it' do
    # 3 collections carry the author, but only the volume is a title the TOC shows a card for
    expect(author.collections.count).to eq(3)
    expect(author.cached_collections_count).to eq(1)
    expect(response.body).to match(%r{#{Regexp.escape(I18n.t(:total_collections_including_author))}:</span>\s*1\s})
  end

  it 'still lists the foreign work in the TOC' do
    expect(response.body).to include('A Foreign Preface')
  end

  it 'shows a TOC count badge matching the metadata card, excluding the foreign work' do
    expect(author.cached_works_count).to eq(3)
    expect(response.body).to include('<span class="count-badge"> (3)</span>')
    expect(response.body).not_to include('<span class="count-badge"> (4)</span>')
  end

  it 'shows the same total in the navbar' do
    navbar = response.body[response.body.index('book-nav-full')...response.body.index('mobile-navbar-backdrop')]
    expect(navbar).to include(" (#{author.cached_works_count})")
    expect(navbar).not_to include(' (4)')
  end
end
