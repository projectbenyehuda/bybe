# frozen_string_literal: true

require 'rails_helper'
include ActiveSupport::Testing::TimeHelpers

describe Collection do
  it 'validates a collection' do
    expect(build(:collection)).to be_valid
    expect { build(:collection, collection_type: 'made_up') }.to raise_error(ArgumentError)
  end

  it 'validates suppress_download_and_print field' do
    collection = build(:collection, suppress_download_and_print: true)
    expect(collection).to be_valid

    collection.suppress_download_and_print = false
    expect(collection).to be_valid

    collection.suppress_download_and_print = nil
    expect(collection).not_to be_valid
  end

  describe 'uncollected type protection' do
    it 'prevents manually creating a collection with uncollected type' do
      collection = build(:collection, collection_type: :uncollected)
      expect(collection.save).to eq false
      expect(collection.errors[:collection_type]).to be_present
    end

    it 'prevents changing collection_type from uncollected to another type' do
      collection = create(:collection, collection_type: :other)
      # Manually set to uncollected to simulate a system-created collection
      collection.update_column(:collection_type, Collection.collection_types[:uncollected])
      collection.reload

      collection.collection_type = :volume
      expect(collection.save).to eq false
      expect(collection.errors[:collection_type]).to be_present
    end

    it 'prevents changing collection_type to uncollected from another type' do
      collection = create(:collection, collection_type: :volume)
      collection.collection_type = :uncollected
      expect(collection.save).to eq false
      expect(collection.errors[:collection_type]).to be_present
    end

    it 'allows updating other attributes of an uncollected collection' do
      collection = create(:collection, collection_type: :other)
      # Manually set to uncollected to simulate a system-created collection
      collection.update_column(:collection_type, Collection.collection_types[:uncollected])
      collection.reload

      collection.title = 'Updated Title'
      expect(collection.save).to eq true
    end
  end

  it 'iterates over its collection_items in order' do
    c = create(:collection)
    i1 = create(:collection_item, collection: c, seqno: 1)
    i2 = create(:collection_item, collection: c, seqno: 3)
    i3 = create(:collection_item, collection: c, seqno: 2)
    c.reload
    expect(c.collection_items).to eq [i1, i3, i2]
  end

  it 'can be queried by type' do
    c1 = create(:collection, collection_type: :series)
    c2 = create(:collection, collection_type: :periodical)
    c3 = create(:collection, collection_type: :periodical)
    c4 = create(:collection, collection_type: :other)
    expect(described_class.by_type(:series)).to eq [c1]
    expect(described_class.by_type(:periodical)).to eq [c2, c3]
    expect(described_class.by_type(:other)).to eq [c4]
    expect(described_class.count).to eq 4
  end

  it 'iterates over its collection items and wrapped polymorphic items filtered by polymorphic item type' do
    c = create(:collection)
    m1 = create(:manifestation)
    m2 = create(:manifestation)
    p1 = create(:person)
    i1 = create(:collection_item, collection: c, seqno: 1, item: m1)
    i2 = create(:collection_item, collection: c, seqno: 3, item: m2)
    i3 = create(:collection_item, collection: c, seqno: 2, item: p1)
    expect(c.collection_items_by_type('Manifestation')).to eq [i1, i2]
    expect(c.collection_items_by_type('Person')).to eq [i3]
    expect(c.collection_items_by_type('Collection').count).to eq 0
    expect(c.items_by_type('Manifestation')).to eq [m1, m2]
    expect(c.items_by_type('Person')).to eq [p1]
    expect(c.items_by_type('Collection').count).to eq 0
  end

  it 'can be queried by tag' do
    c1 = create(:collection)
    c2 = create(:collection)
    c3 = create(:collection)
    t1 = create(:tag)
    t2 = create(:tag)
    t3 = create(:tag)
    create(:tagging, tag: t1, taggable: c1)
    create(:tagging, tag: t2, taggable: c1)
    create(:tagging, tag: t2, taggable: c2)
    create(:tagging, tag: t3, taggable: c3)
    expect(described_class.by_tag(t1.id)).to eq [c1]
    expect(described_class.by_tag(t2.id)).to eq [c1, c2]
    expect(described_class.by_tag(t3.id)).to eq [c3]
  end

  it 'has access to an optional associated custom TOC' do
    c = create(:collection)
    t = create(:toc)
    c.toc = t
    c.save!
    expect(c.toc).to eq t
  end

  it 'has access to an optional associated Publication' do
    c = create(:collection)
    p = create(:publication)
    c.publication = p
    c.save!
    expect(c.publication).to eq p
  end

  pending 'lists people associated with it, optionally filtered by role'

  it 'lists tags associated with it' do
    c = create(:collection)
    t1 = create(:tag)
    t2 = create(:tag)
    t3 = create(:tag)
    create(:tagging, tag: t1, taggable: c)
    create(:tagging, tag: t2, taggable: c)
    create(:tagging, tag: t3, taggable: c)
    expect(c.tags).to eq [t1, t2, t3]
  end

  it 'can move an item up in the order' do
    c = create(:collection)
    i1 = create(:collection_item, collection: c, seqno: 1)
    i2 = create(:collection_item, collection: c, seqno: 3)
    i3 = create(:collection_item, collection: c, seqno: 2)
    c.reload
    expect(c.collection_items).to eq [i1, i3, i2]
    c.move_item_up(i2.id)
    expect(c.collection_items.reload).to eq [i1, i2, i3]
  end

  it 'can move an item down in the order' do
    c = create(:collection)
    i1 = create(:collection_item, collection: c, seqno: 1)
    i2 = create(:collection_item, collection: c, seqno: 3)
    i3 = create(:collection_item, collection: c, seqno: 2)
    c.reload
    expect(c.collection_items).to eq [i1, i3, i2]
    c.move_item_down(i1.id)
    expect(c.collection_items.reload).to eq [i3, i1, i2]
  end

  it 'can append an item to the end of the order' do
    c = create(:collection)
    i1 = create(:collection_item, collection: c, seqno: 1)
    i2 = create(:collection_item, collection: c, seqno: 3)
    i3 = create(:collection_item, collection: c, seqno: 2)
    c.reload
    expect(c.collection_items).to eq [i1, i3, i2]
    m = create(:manifestation)
    c.append_item(m)
    expect(c.collection_items.reload.count).to eq 4
    expect(c.collection_items.last.item).to eq m
  end

  it 'can be emptied' do
    c = create(:collection)
    create_list(:collection_item, 5, collection: c)
    expect(c.collection_items.count).to eq 5
    c.reload
    c.collection_items.destroy_all
    expect(c.collection_items.count).to eq 0
  end

  it 'removes an item' do
    c = create(:collection)
    i1 = create(:collection_item, collection: c, seqno: 1)
    i2 = create(:collection_item, collection: c, seqno: 3)
    i3 = create(:collection_item, collection: c, seqno: 2)
    expect(c.collection_items.count).to eq 3
    c.remove_item(i3.id)
    c.reload
    expect(c.collection_items.count).to eq 2
    expect(c.collection_items.first).to eq i1
    expect(c.collection_items.last).to eq i2
  end

  describe '.insert_item_at' do
    subject(:call) { collection.insert_item_at(manifestation, index) }

    let(:collection) { create(:collection) }
    let(:manifestation) { create(:manifestation) }
    let(:index) { 1 }

    let!(:first_item) { create(:collection_item, collection: collection, seqno: 1) }
    let!(:second_item) { create(:collection_item, collection: collection, seqno: 2) }
    let!(:third_item) { create(:collection_item, collection: collection, seqno: 3) }

    let(:inserted_item) { CollectionItem.order(id: :desc).first }

    before do
      collection.reload
      call
      collection.reload
    end

    context 'when insert at the end of the list' do
      let(:index) { 4 }

      it 'inserts successfully' do
        expect(inserted_item).to have_attributes(seqno: 4, item: manifestation)
        expect(collection.collection_items).to eq [first_item, second_item, third_item, inserted_item]
        expect(collection.collection_items.map(&:seqno)).to eq [1, 2, 3, 4]
      end
    end

    context 'when insert at the beginning of the list' do
      let(:index) { 1 }

      it 'inserts successfully' do
        expect(inserted_item).to have_attributes(seqno: 1, item: manifestation)
        expect(collection.collection_items).to eq [inserted_item, first_item, second_item, third_item]
        expect(collection.collection_items.map(&:seqno)).to eq [1, 2, 3, 4]
      end
    end

    context 'when insert at specified position' do
      let(:index) { 2 }

      it 'inserts successfully' do
        expect(inserted_item).to have_attributes(seqno: 2, item: manifestation)
        expect(collection.collection_items).to eq [first_item, inserted_item, second_item, third_item]
        expect(collection.collection_items.map(&:seqno)).to eq [1, 2, 3, 4]
      end
    end

    context 'when calling insert beyond cached size (exposes caching bug)' do
      it 'correctly inserts at position beyond stale cached size' do
        collection = create(:collection)
        create(:collection_item, collection: collection, seqno: 1, alt_title: 'A')
        create(:collection_item, collection: collection, seqno: 2, alt_title: 'B')
        create(:collection_item, collection: collection, seqno: 3, alt_title: 'C')

        # First insert loads and caches collection_items (size=3)
        item1 = create(:manifestation)
        collection.insert_item_at(item1, 2)

        # DB now has 4 items, but cache still thinks size=3
        # Insert at position 5 (beyond both cached and actual size)
        # BUGGY: pos(5) > cached_size(3), uses cached.last.seqno + 1 = 3 + 1 = 4
        # FIXED: pos(5) > actual_size(4), uses actual.last.seqno + 1 = 4 + 1 = 5
        item2 = create(:manifestation)
        collection.insert_item_at(item2, 5)

        # Verify
        collection.reload
        seqnos = collection.collection_items.pluck(:seqno)

        # Should be: 1, 2, 3, 4, 5 (item2 appended with seqno 5)
        expect(seqnos).to eq([1, 2, 3, 4, 5])
      end
    end

    context 'when association cached via array indexing before insert' do
      it 'uses correct seqno despite cached array' do
        collection = create(:collection)
        item_a = create(:collection_item, collection: collection, seqno: 1, alt_title: 'A')
        item_b = create(:collection_item, collection: collection, seqno: 2, alt_title: 'B')
        item_c = create(:collection_item, collection: collection, seqno: 3, alt_title: 'C')

        # Access via array indexing - this caches the association as an array
        expect(collection.collection_items[0].alt_title).to eq('A')
        expect(collection.collection_items[1].alt_title).to eq('B')

        # Modify database to create gaps
        item_b.update_column(:seqno, 5)
        item_c.update_column(:seqno, 10)

        # Insert should use fresh data, not cached
        new_item = create(:manifestation)
        collection.insert_item_at(new_item, 2)

        # Verify
        collection.reload
        seqnos = collection.collection_items.order(:seqno).pluck(:seqno)
        expect(seqnos).to eq([1, 5, 6, 11])  # NEW at 5, B at 6, C at 11
      end
    end

    context 'with larger collection and multiple appends' do
      it 'correctly appends when position exceeds stale cached size' do
        collection = create(:collection)
        5.times do |i|
          create(:collection_item, collection: collection, seqno: i + 1, alt_title: "Item#{i + 1}")
        end

        # Perform 3 appends at the end without reloading
        # Each append uses position = current_size + 1
        # But cache thinks size is always 5
        3.times do |i|
          item = create(:manifestation)
          # Try to append at the end by using a large position
          collection.insert_item_at(item, 10 + i)  # positions 10, 11, 12 (all > size)
        end

        # Verify all items are in correct order with correct seqnos
        collection.reload
        seqnos = collection.collection_items.pluck(:seqno)

        # Should have 8 items with increasing seqnos
        expect(seqnos.size).to eq(8)
        expect(seqnos).to eq([1, 2, 3, 4, 5, 6, 7, 8])
      end
    end

    context 'when size checked before modification' do
      it 'gets correct position despite stale size' do
        collection = create(:collection)
        create(:collection_item, collection: collection, seqno: 1, alt_title: 'A')
        create(:collection_item, collection: collection, seqno: 2, alt_title: 'B')
        create(:collection_item, collection: collection, seqno: 3, alt_title: 'C')

        # Check size to cache it
        expect(collection.collection_items.size).to eq(3)

        # Modify seqnos to create gaps
        collection.collection_items[1].update_column(:seqno, 10)
        collection.collection_items[2].update_column(:seqno, 20)

        # Insert at position 2 - should use fresh seqno data
        new_item = create(:manifestation)
        collection.insert_item_at(new_item, 2)

        # Verify
        collection.reload
        seqnos = collection.collection_items.order(:seqno).pluck(:seqno)
        expect(seqnos).to eq([1, 10, 11, 21])  # NEW at 10, B at 11, C at 21
      end
    end
  end

  it 'knows its parent collections' do
    c = create(:collection)
    p1 = create(:collection)
    p2 = create(:collection)
    create(:collection_item, collection: c, seqno: 1)
    create(:collection_item, collection: p1, seqno: 1, item: c)
    create(:collection_item, collection: p2, seqno: 1, item: c)
    expect(c.parent_collections).to eq [p1, p2]
  end

  describe '#fresh_downloadable_for' do
    let(:collection) { create(:collection) }

    context 'when downloadable has attached file' do
      let!(:downloadable) { create(:downloadable, :with_file, object: collection, doctype: :pdf) }

      it 'returns the downloadable' do
        expect(collection.fresh_downloadable_for('pdf')).to eq downloadable
      end
    end

    context 'when downloadable exists but has no attached file' do
      let!(:downloadable) { create(:downloadable, :without_file, object: collection, doctype: :pdf) }

      it 'returns nil' do
        expect(collection.fresh_downloadable_for('pdf')).to be_nil
      end
    end

    context 'when no downloadable exists' do
      it 'returns nil' do
        expect(collection.fresh_downloadable_for('pdf')).to be_nil
      end
    end
  end
end
