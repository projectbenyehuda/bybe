# frozen_string_literal: true

require 'rails_helper'

describe TocTree::CollectionNode do
  let(:authority) { create(:authority) }
  let(:other_authority) { create(:authority) }
  let(:edited_collection) { create(:collection, editors: [authority], authors: [authority]) }
  let(:manifestation) { create(:manifestation, author: other_authority, editor: authority) }
  let(:node) do
    described_class.new(edited_collection).tap do |n|
      n.add_child(TocTree::ManifestationNode.new(manifestation), 1)
    end
  end

  describe '#collapsed_for?' do
    it 'is true for the editor of the collection under the editor role' do
      expect(node.collapsed_for?(:editor, authority.id)).to be(true)
    end

    it 'is false for the same authority under another role it holds on the collection' do
      expect(node.collapsed_for?(:author, authority.id)).to be(false)
    end

    it 'is false for an authority not editing the collection' do
      expect(node.collapsed_for?(:editor, other_authority.id)).to be(false)
    end
  end

  describe '#children_by_role' do
    it "lists no texts of an edited collection on its editor's page" do
      expect(node.children_by_role(:editor, authority.id, true)).to be_empty
    end

    it 'keeps the edited collection itself visible at collection level' do
      expect(node.visible?(:editor, authority.id, true)).to be(true)
    end

    it 'lists the texts under other roles' do
      expect(node.children_by_role(:author, authority.id, true).map(&:manifestation)).to eq([manifestation])
    end
  end

  describe '#count_manifestations' do
    it "counts nothing in an edited collection on its editor's page" do
      expect(node.count_manifestations(:editor, authority.id, true)).to eq(0)
    end
  end
end
