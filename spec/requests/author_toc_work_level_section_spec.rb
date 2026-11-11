# frozen_string_literal: true

require 'rails_helper'

# The work-level section of an authority's TOC lists their works in titles that are not their own.
# Those may be others' volumes, but also periodicals the authority edits, so the section heading reflects
# which of the two it holds; and a series the authority is credited on, nested in someone else's volume,
# is listed there as well, rather than as one of the authority's own titles.
RSpec.describe 'Authority TOC work-level section', type: :request do
  subject(:call) { get authority_path(author) }

  let(:author) do
    create(:authority, :published, gender: 'female', uncollected_works_collection: create(:collection, :uncollected))
  end
  let(:other_authority) { create(:authority) }
  let(:own_article) { create(:manifestation, title: 'An Own Article', author: author) }
  let!(:periodical) do
    issue = create(:collection, collection_type: :periodical_issue, manifestations: [own_article])
    create(:collection, title: 'Edited Periodical', collection_type: :periodical, editors: [author],
                        included_collections: [issue])
  end

  around { |example| I18n.with_locale(:he) { example.run } }

  context 'when the section holds only periodicals the authority edits' do
    before { call }

    it 'is headed as titles she edited, in the TOC body and in the navbar' do
      expect(response.body).to include('id="works-author-work-level"')
      expect(response.body.scan('כותרים בעריכתה').size).to eq(2)
      expect(navbar_fragment(response.body)).to include('כותרים בעריכתה')
      expect(response.body).not_to include('בכותרים של אחרים')
    end
  end

  context "when the section also holds a series she wrote in somebody else's volume" do
    let(:foreign_poem) { create(:manifestation, title: 'A Foreign Poem', author: other_authority) }
    let(:series) do
      create(:collection, title: 'Her Cycle', collection_type: :series, authors: [author],
                          manifestations: [create(:manifestation, title: 'Her Poem', author: author), foreign_poem])
    end
    let!(:volume) do
      create(:collection, title: 'Somebody Elses Anthology', collection_type: :volume, authors: [other_authority],
                          included_collections: [series])
    end

    before { call }

    it 'lists the volume on work level rather than among her own titles' do
      expect(response.body).not_to include('id="works-author-collection-level"')
      expect(response.body).to include(%(id="cwrapper_author_work_#{volume.id}"))
    end

    it 'lists the whole series, including works by others' do
      expect(response.body).to include('Her Poem')
      expect(response.body).to include(%(href="#{manifestation_path(foreign_poem)}"))
    end

    it 'is headed as titles by others and periodicals, in the TOC body and in the navbar' do
      expect(response.body.scan('בכותרים של אחרים ובכתבי עת').size).to eq(2)
      expect(navbar_fragment(response.body)).to include('בכותרים של אחרים ובכתבי עת')
    end
  end
end
