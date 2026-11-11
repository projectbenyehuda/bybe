# frozen_string_literal: true

require 'rails_helper'

# Credit on a series nested in another collection (a cycle of poems in an anthology, a column in a
# periodical issue) does not make the enclosing title one of the authority's own: the enclosing title
# is listed on work level, with the credited series in its entirety.
describe TocTree::CollectionNode, '#visible?' do
  include AuthorsHelper

  let(:authority) { create(:authority) }
  let(:other_authority) { create(:authority) }
  let(:own_work) { create(:manifestation, title: 'Own Poem', author: authority) }
  let(:foreign_work) { create(:manifestation, title: 'Foreign Poem', author: other_authority) }
  let(:series) do
    create(:collection, collection_type: :series, authors: [authority],
                        manifestations: [own_work, foreign_work], title_placeholders: ['A placeholder'])
  end
  let(:other_work) { create(:manifestation, title: 'Unrelated Poem', author: other_authority) }
  let(:volume_authors) { [other_authority] }
  let!(:volume) do
    create(:collection, collection_type: :volume, authors: volume_authors,
                        included_collections: [series], manifestations: [other_work])
  end

  let(:top_nodes) { GenerateTocTree.call(authority).top_level_nodes }
  let(:sections) { toc_role_sections(top_nodes, 'author', authority.id) }
  let(:volume_node) { top_nodes.find { |node| node.collection == volume } }

  def listed_items(node, involved_on_collection_level)
    node.children_by_role('author', authority.id, involved_on_collection_level).flat_map do |child|
      case child
      when TocTree::CollectionNode then [child.collection] + listed_items(child, involved_on_collection_level)
      when TocTree::ManifestationNode then [child.manifestation]
      else [child.collection_item.alt_title]
      end
    end
  end

  it 'is a nested series' do
    expect(series.reload.nested_series?).to be(true)
  end

  context 'when the authority is credited on the series only' do
    it 'does not list the enclosing volume on collection level' do
      expect(sections[:collection_level]).to be_empty
    end

    it 'lists the enclosing volume on work level' do
      expect(sections[:work_level].map(&:collection)).to eq([volume])
    end

    it "lists the series in its entirety, but not the volume's other contents" do
      expect(listed_items(volume_node, false)).to eq([series, own_work, foreign_work, 'A placeholder'])
    end

    it "counts only the authority's own works" do
      expect(volume_node.count_manifestations('author', authority.id, false)).to eq(1)
    end
  end

  context 'when the authority is credited on the enclosing volume too' do
    let(:volume_authors) { [authority] }

    it 'lists the volume, with all its contents, on collection level only' do
      expect(sections[:collection_level].map(&:collection)).to eq([volume])
      expect(sections[:work_level]).to be_empty
      expect(listed_items(volume_node, true)).to contain_exactly(series, own_work, foreign_work, 'A placeholder',
                                                                 other_work)
    end
  end

  context 'when the credited series is not nested in any other collection' do
    let!(:volume) { nil }

    before { series }

    it 'is not a nested series' do
      expect(series.reload.nested_series?).to be(false)
    end

    it 'is still listed on collection level' do
      expect(sections[:collection_level].map(&:collection)).to eq([series])
      expect(sections[:work_level]).to be_empty
    end
  end

  context 'when the series is nested in a series nested in a periodical issue' do
    let!(:volume) { nil }
    let!(:issue) do
      outer = create(:collection, collection_type: :series, included_collections: [series])
      create(:collection, collection_type: :periodical_issue, authors: [other_authority],
                          included_collections: [outer])
    end

    it 'lists the issue on work level, with the credited series in its entirety' do
      expect(sections[:collection_level]).to be_empty
      issue_node = sections[:work_level].sole
      expect(issue_node.collection).to eq(issue)
      expect(listed_items(issue_node, false)).to include(series, own_work, foreign_work, 'A placeholder')
    end
  end
end
