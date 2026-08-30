# frozen_string_literal: true

require 'rails_helper'

describe GenerateTocTree do
  subject(:result) { described_class.call(authority).top_level_nodes }

  let!(:authority) { create(:authority, uncollected_works_collection: uncollected_collection) }

  context 'when there are no works or collections' do
    let(:uncollected_collection) { nil }

    it { is_expected.to be_empty }
  end

  context 'when there are works' do
    include_context 'when authority has several collections'

    let(:top_level_node) { find_collection_node(result, top_level_collection) }
    let(:top_level_with_nested_node) { find_collection_node(result, top_level_collection_with_nested_collections) }
    let(:uncollected_node) { find_collection_node(result, uncollected_collection) }
    let(:nested_edited_node) { find_child_node(top_level_with_nested_node, nested_edited_collection) }
    let(:nested_translated_node) { find_child_node(top_level_with_nested_node, nested_translated_collection) }
    let(:nested_translated_subnode) { find_child_node(nested_translated_node, nested_translated_subcollection) }

    it 'runs successfully' do
      expect(result).to contain_exactly top_level_node, top_level_with_nested_node, uncollected_node

      expect(top_level_node.children.map(&:first).map(&:manifestation)).to match_array top_level_manifestations
      expect(
        top_level_with_nested_node.children.map { |c| c.first.collection }
      ).to contain_exactly nested_translated_collection,
                           nested_edited_collection

      expect(nested_edited_node.children.map(&:first).map(&:manifestation)).to match_array edited_manifestations
      expect(nested_translated_node.children.map(&:first).map(&:id)).to match_array(
        translated_manifestations.map { |m| "manifestation:#{m.id}" } +
          ["collection:#{nested_translated_subcollection.id}"]
      )
      expect(nested_translated_subnode.children.map(&:first).map(&:alt_title)).to contain_exactly(
        'Title placeholder', nil
      )
      expect(nested_translated_subnode.children.map(&:first).map(&:markdown)).to contain_exactly(
        nil, 'Markdown placeholder'
      )
    end

    context 'with count_manifestations' do
      it 'counts manifestations correctly for top-level collection at work level' do
        # top_level_collection doesn't have authority involved at collection level,
        # only at work level (manifestations have author: authority)
        count = top_level_node.count_manifestations(:author, authority.id, false)
        expect(count).to eq(top_level_manifestations.count)
      end

      it 'counts manifestations correctly for nested collections' do
        # Count edited manifestations (editor role, collection level)
        edited_count = nested_edited_node.count_manifestations(:editor, authority.id, true)
        expect(edited_count).to eq(edited_manifestations.count)
      end

      it 'counts manifestations correctly for uncollected works' do
        # Count uncollected manifestations (author role, work level)
        uncollected_count = uncollected_node.count_manifestations(:author, authority.id, false)
        expect(uncollected_count).to eq(uncollected_manifestations.count)
      end

      it 'returns 0 for placeholders' do
        placeholder_node = nested_translated_subnode.children.map(&:first).find do |child|
          child.is_a?(TocTree::PlaceholderNode)
        end
        expect(placeholder_node.count_manifestations(:translator, authority.id, true)).to eq(0)
      end

      it 'counts manifestations recursively in nested structure' do
        # nested_edited_collection sits under top_level_collection_with_nested_collections, and its
        # manifestations do carry the authority as editor, so the recursive sum reaches them.
        total_edited = top_level_with_nested_node.count_manifestations(:editor, authority.id, true)
        expect(total_edited).to eq(edited_manifestations.count)
      end

      it 'does not count works the authority is only involved in through the collection' do
        # translated_manifestations have no translator involvement of their own (see the shared
        # context) -- the authority is a translator of nested_translated_collection only. They are
        # still rendered in the TOC, but counting them would push these badges above the metadata
        # card's 'works in the project' figure, which counts direct involvements only.
        total_translated = top_level_with_nested_node.count_manifestations(:translator, authority.id, true)
        expect(total_translated).to eq(0)
      end

      it 'returns 0 for invisible manifestations' do
        manifestation_node = TocTree::ManifestationNode.new(top_level_manifestations.first)
        # Should return 0 when checking for a role the authority doesn't have
        count = manifestation_node.count_manifestations(:translator, authority.id, false)
        expect(count).to eq(0)
      end

      it 'returns 1 for visible published manifestations' do
        manifestation_node = TocTree::ManifestationNode.new(top_level_manifestations.first)
        # Should return 1 when checking for author role
        count = manifestation_node.count_manifestations(:author, authority.id, false)
        expect(count).to eq(1)
      end

      it 'returns 0 for unpublished manifestations' do
        unpublished = create(:manifestation, author: authority, collections: [top_level_collection], status: 'unpublished')
        manifestation_node = TocTree::ManifestationNode.new(unpublished)
        count = manifestation_node.count_manifestations(:author, authority.id, false)
        expect(count).to eq(0)
      end
    end
  end

  # Reproduces benyehuda.org/author/1024: the metadata card said 36 works while the TOC badge said
  # 38, because the two prefaces other people contributed to Alon's volumes were counted as his.
  context "when the authority's own volume also holds a work by somebody else" do
    let(:uncollected_collection) { create(:collection, :uncollected) }
    let(:other_authority) { create(:authority) }
    let!(:volume) { create(:collection, collection_type: :volume, authors: [authority]) }
    let!(:own_works) { create_list(:manifestation, 3, author: authority, collections: [volume]) }
    let!(:foreign_preface) { create(:manifestation, author: other_authority, collections: [volume]) }

    let(:volume_node) { find_collection_node(result, volume) }

    it 'still lists the foreign work in the TOC' do
      listed = volume_node.children_by_role(:author, authority.id, true).map(&:id)
      expect(listed).to include("manifestation:#{foreign_preface.id}")
    end

    it 'counts only the works the authority is actually involved in' do
      expect(volume_node.count_manifestations(:author, authority.id, true)).to eq(own_works.count)
    end

    it "agrees with the authority's published works count" do
      expect(volume_node.count_manifestations(:author, authority.id, true))
        .to eq(authority.published_manifestations.count)
    end
  end

  private

  def find_collection_node(nodes, collection)
    nodes.find { |n| n.collection == collection }
  end

  def find_child_node(parent_node, item)
    find_collection_node(parent_node.children.map(&:first), item)
  end
end
