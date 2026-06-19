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

  it 'can query for pby volumes' do
    # Create PBY authority with ID from constant
    pby = Authority.create!(id: Authority::PBY_AUTHORITY_ID, name: 'Project Ben-Yehuda', status: :published,
                            intellectual_property: :public_domain, person: create(:person))
    other_auth = create(:authority)

    # Create volumes
    v1 = create(:collection, collection_type: :volume)
    v2 = create(:collection, collection_type: :volume)
    v3 = create(:collection, collection_type: :volume)

    # Create non-volume collection
    periodical = create(:collection, collection_type: :periodical)

    # Associate authorities with collections
    create(:involved_authority, item: v1, authority: pby)
    create(:involved_authority, item: v2, authority: pby)
    create(:involved_authority, item: v3, authority: other_auth)
    create(:involved_authority, item: periodical, authority: pby)

    # Should only return volumes with PBY authority (ID 3358)
    expect(described_class.pby_volumes).to contain_exactly(v1, v2)
  end

  it 'supports volume_series collection type' do
    c = create(:collection, collection_type: :volume_series)
    expect(c).to be_valid
    expect(c.volume_series?).to be true
    expect(c.periodical?).to be false
    expect(described_class.by_type(:volume_series)).to eq [c]
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

  describe 'credits cache invalidation' do
    it 'clears cached_credits when credits changes' do
      c = create(:collection, credits: 'Original credits')
      c.update_column(:cached_credits, 'Cached value')
      c.reload
      c.update!(credits: 'Updated credits')
      expect(c.reload.cached_credits).to be_nil
    end

    it 'does not clear cached_credits when credits is unchanged' do
      c = create(:collection, credits: 'Some credits')
      c.update_column(:cached_credits, 'Cached value')
      c.reload
      c.update!(title: 'New Title')
      expect(c.reload.cached_credits).to eq 'Cached value'
    end
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

  describe '#publisher_link' do
    let(:collection) { create(:collection) }

    context 'when collection has a publisher_site external link' do
      let!(:publisher_link) do
        create(:external_link, linkable: collection, linktype: :publisher_site, url: 'https://example.com',
                               description: 'Test Publisher')
      end

      it 'returns the publisher link' do
        expect(collection.publisher_link).to eq publisher_link
      end
    end

    context 'when collection has no publisher link but parent collection does' do
      let(:parent_collection) { create(:collection) }
      let!(:publisher_link) do
        create(:external_link, linkable: parent_collection, linktype: :publisher_site, url: 'https://example.com',
                               description: 'Test Publisher')
      end

      before do
        create(:collection_item, collection: parent_collection, item: collection)
      end

      it 'returns the parent collection publisher link' do
        expect(collection.publisher_link).to eq publisher_link
      end
    end

    context 'when collection has no publisher link and no parent has one' do
      it 'returns nil' do
        expect(collection.publisher_link).to be_nil
      end
    end

    context 'when collection has publisher link and parent also has one' do
      let(:parent_collection) { create(:collection) }
      let!(:collection_link) do
        create(:external_link, linkable: collection, linktype: :publisher_site, url: 'https://collection.com',
                               description: 'Collection Publisher')
      end
      let!(:parent_link) do
        create(:external_link, linkable: parent_collection, linktype: :publisher_site, url: 'https://parent.com',
                               description: 'Parent Publisher')
      end

      before do
        create(:collection_item, collection: parent_collection, item: collection)
      end

      it 'returns the collection own link, not the parent' do
        expect(collection.publisher_link).to eq collection_link
      end
    end

    context 'when collection has nested parent collections with publisher links' do
      let(:grandparent_collection) { create(:collection) }
      let(:parent_collection) { create(:collection) }
      let!(:grandparent_link) do
        create(:external_link, linkable: grandparent_collection, linktype: :publisher_site,
                               url: 'https://grandparent.com', description: 'Grandparent Publisher')
      end

      before do
        create(:collection_item, collection: grandparent_collection, item: parent_collection)
        create(:collection_item, collection: parent_collection, item: collection)
      end

      it 'cascades to find the grandparent link' do
        expect(collection.publisher_link).to eq grandparent_link
      end
    end
  end

  describe 'external_links association' do
    let(:collection) { create(:collection) }

    it 'can have associated external links' do
      link1 = create(:external_link, linkable: collection, linktype: :wikipedia)
      link2 = create(:external_link, linkable: collection, linktype: :publisher_site)

      expect(collection.external_links).to contain_exactly(link1, link2)
    end

    it 'deletes associated external links when collection is destroyed' do
      create(:external_link, linkable: collection, linktype: :publisher_site)

      expect { collection.destroy! }.to change(ExternalLink, :count).by(-1)
    end
  end

  describe 'manifestations_count counter cache' do
    let(:collection) { create(:collection) }

    context 'basic counting' do
      it 'starts with zero count' do
        expect(collection.manifestations_count).to eq 0
      end

      it 'counts a single manifestation' do
        m1 = create(:manifestation)
        create(:collection_item, collection: collection, item: m1, seqno: 1)
        collection.reload
        expect(collection.manifestations_count).to eq 1
      end

      it 'counts multiple manifestations' do
        m1 = create(:manifestation)
        m2 = create(:manifestation)
        m3 = create(:manifestation)
        create(:collection_item, collection: collection, item: m1, seqno: 1)
        create(:collection_item, collection: collection, item: m2, seqno: 2)
        create(:collection_item, collection: collection, item: m3, seqno: 3)
        collection.reload
        expect(collection.manifestations_count).to eq 3
      end

      it 'does not count non-manifestation items' do
        m1 = create(:manifestation)
        p1 = create(:person)
        create(:collection_item, collection: collection, item: m1, seqno: 1)
        create(:collection_item, collection: collection, item: p1, seqno: 2)
        collection.reload
        expect(collection.manifestations_count).to eq 1
      end

      it 'does not count placeholder items' do
        m1 = create(:manifestation)
        create(:collection_item, collection: collection, item: m1, seqno: 1)
        create(:collection_item, collection: collection, item: nil, alt_title: 'Placeholder', seqno: 2)
        collection.reload
        expect(collection.manifestations_count).to eq 1
      end
    end

    context 'nested collections' do
      it 'counts manifestations in nested collections' do
        m1 = create(:manifestation)
        m2 = create(:manifestation)
        nested_collection = create(:collection)

        create(:collection_item, collection: nested_collection, item: m1, seqno: 1)
        create(:collection_item, collection: nested_collection, item: m2, seqno: 2)
        create(:collection_item, collection: collection, item: nested_collection, seqno: 1)

        collection.reload
        expect(collection.manifestations_count).to eq 2
      end

      it 'counts manifestations from both direct items and nested collections' do
        m1 = create(:manifestation)
        m2 = create(:manifestation)
        m3 = create(:manifestation)
        nested_collection = create(:collection)

        create(:collection_item, collection: collection, item: m1, seqno: 1)
        create(:collection_item, collection: nested_collection, item: m2, seqno: 1)
        create(:collection_item, collection: nested_collection, item: m3, seqno: 2)
        create(:collection_item, collection: collection, item: nested_collection, seqno: 2)

        collection.reload
        expect(collection.manifestations_count).to eq 3
      end

      it 'handles deeply nested collections (3 levels)' do
        m1 = create(:manifestation)
        m2 = create(:manifestation)
        m3 = create(:manifestation)

        level3_collection = create(:collection)
        level2_collection = create(:collection)

        create(:collection_item, collection: level3_collection, item: m1, seqno: 1)
        create(:collection_item, collection: level2_collection, item: m2, seqno: 1)
        create(:collection_item, collection: level2_collection, item: level3_collection, seqno: 2)
        create(:collection_item, collection: collection, item: m3, seqno: 1)
        create(:collection_item, collection: collection, item: level2_collection, seqno: 2)

        collection.reload
        expect(collection.manifestations_count).to eq 3
      end

      it 'handles multiple nested collections at the same level' do
        m1 = create(:manifestation)
        m2 = create(:manifestation)
        m3 = create(:manifestation)

        nested1 = create(:collection)
        nested2 = create(:collection)

        create(:collection_item, collection: nested1, item: m1, seqno: 1)
        create(:collection_item, collection: nested2, item: m2, seqno: 1)
        create(:collection_item, collection: nested2, item: m3, seqno: 2)
        create(:collection_item, collection: collection, item: nested1, seqno: 1)
        create(:collection_item, collection: collection, item: nested2, seqno: 2)

        collection.reload
        expect(collection.manifestations_count).to eq 3
      end
    end

    context 'automatic updates on item changes' do
      it 'increments count when a manifestation is added' do
        expect(collection.manifestations_count).to eq 0

        m1 = create(:manifestation)
        create(:collection_item, collection: collection, item: m1, seqno: 1)

        collection.reload
        expect(collection.manifestations_count).to eq 1
      end

      it 'decrements count when a manifestation is removed' do
        m1 = create(:manifestation)
        ci = create(:collection_item, collection: collection, item: m1, seqno: 1)
        collection.reload
        expect(collection.manifestations_count).to eq 1

        ci.destroy!
        collection.reload
        expect(collection.manifestations_count).to eq 0
      end

      it 'updates count when collection item type changes' do
        m1 = create(:manifestation)
        p1 = create(:person)
        ci = create(:collection_item, collection: collection, item: m1, seqno: 1)
        collection.reload
        expect(collection.manifestations_count).to eq 1

        ci.update!(item: p1)
        collection.reload
        expect(collection.manifestations_count).to eq 0
      end
    end

    context 'propagation to parent collections' do
      it 'updates parent collection when nested collection changes' do
        parent = create(:collection)
        nested = create(:collection)
        create(:collection_item, collection: parent, item: nested, seqno: 1)

        parent.reload
        nested.reload
        expect(parent.manifestations_count).to eq 0
        expect(nested.manifestations_count).to eq 0

        m1 = create(:manifestation)
        create(:collection_item, collection: nested, item: m1, seqno: 1)

        parent.reload
        nested.reload
        expect(nested.manifestations_count).to eq 1
        expect(parent.manifestations_count).to eq 1
      end

      it 'propagates changes through multiple levels' do
        grandparent = create(:collection)
        parent = create(:collection)
        child = create(:collection)

        create(:collection_item, collection: grandparent, item: parent, seqno: 1)
        create(:collection_item, collection: parent, item: child, seqno: 1)

        m1 = create(:manifestation)
        create(:collection_item, collection: child, item: m1, seqno: 1)

        grandparent.reload
        parent.reload
        child.reload

        expect(child.manifestations_count).to eq 1
        expect(parent.manifestations_count).to eq 1
        expect(grandparent.manifestations_count).to eq 1
      end

      it 'updates all parent collections when item is removed from nested collection' do
        grandparent = create(:collection)
        parent = create(:collection)
        child = create(:collection)

        create(:collection_item, collection: grandparent, item: parent, seqno: 1)
        create(:collection_item, collection: parent, item: child, seqno: 1)

        m1 = create(:manifestation)
        ci = create(:collection_item, collection: child, item: m1, seqno: 1)

        grandparent.reload
        parent.reload
        child.reload
        expect(child.manifestations_count).to eq 1
        expect(parent.manifestations_count).to eq 1
        expect(grandparent.manifestations_count).to eq 1

        ci.destroy!

        grandparent.reload
        parent.reload
        child.reload
        expect(child.manifestations_count).to eq 0
        expect(parent.manifestations_count).to eq 0
        expect(grandparent.manifestations_count).to eq 0
      end
    end

    context 'manual recalculation' do
      it 'recalculates count correctly' do
        m1 = create(:manifestation)
        m2 = create(:manifestation)
        create(:collection_item, collection: collection, item: m1, seqno: 1)
        create(:collection_item, collection: collection, item: m2, seqno: 2)

        # Manually corrupt the count
        collection.update_column(:manifestations_count, 999)
        expect(collection.manifestations_count).to eq 999

        # Recalculate
        collection.recalculate_manifestations_count!
        expect(collection.manifestations_count).to eq 2
      end

      it 'recalculates count for nested collections' do
        m1 = create(:manifestation)
        m2 = create(:manifestation)
        nested = create(:collection)

        create(:collection_item, collection: collection, item: m1, seqno: 1)
        create(:collection_item, collection: nested, item: m2, seqno: 1)
        create(:collection_item, collection: collection, item: nested, seqno: 2)

        # Manually corrupt the count
        collection.update_column(:manifestations_count, 999)

        # Recalculate
        collection.recalculate_manifestations_count!
        expect(collection.manifestations_count).to eq 2
      end
    end

    context 'edge cases' do
      it 'handles empty nested collections' do
        empty_nested = create(:collection)
        create(:collection_item, collection: collection, item: empty_nested, seqno: 1)

        collection.reload
        expect(collection.manifestations_count).to eq 0
      end

      it 'handles collection with only non-manifestation items' do
        p1 = create(:person)
        p2 = create(:person)
        create(:collection_item, collection: collection, item: p1, seqno: 1)
        create(:collection_item, collection: collection, item: p2, seqno: 2)

        collection.reload
        expect(collection.manifestations_count).to eq 0
      end

      it 'handles adding and removing nested collections with manifestations' do
        m1 = create(:manifestation)
        nested = create(:collection)
        create(:collection_item, collection: nested, item: m1, seqno: 1)

        ci = create(:collection_item, collection: collection, item: nested, seqno: 1)
        collection.reload
        expect(collection.manifestations_count).to eq 1

        ci.destroy!
        collection.reload
        expect(collection.manifestations_count).to eq 0
      end
    end
  end

  describe '#update_alternate_titles' do
    let(:collection) { create(:collection, title: 'פִּתְאֹם') }

    it 'updates alternate_titles with forms from AlternateHebrewForms service' do
      collection.update_alternate_titles
      expect(collection.alternate_titles).to eq('פתאם; פיתאום')
    end

    it 'preserves existing alternate titles and adds new ones' do
      collection.update_column(:alternate_titles, 'עוד משהו')
      collection.update_alternate_titles
      expect(collection.alternate_titles).to eq('עוד משהו; פתאם; פיתאום')
    end

    it 'removes duplicates when combining existing and new alternate forms' do
      collection.update_column(:alternate_titles, 'פיתאום')
      collection.update_alternate_titles
      expect(collection.alternate_titles).to eq('פיתאום; פתאם')
    end

    it 'handles empty existing alternate_titles' do
      collection.update_column(:alternate_titles, '')
      collection.update_alternate_titles
      expect(collection.alternate_titles).to eq('פתאם; פיתאום')
    end

    it 'handles nil existing alternate_titles' do
      collection.update_column(:alternate_titles, nil)
      collection.update_alternate_titles
      expect(collection.alternate_titles).to eq('פתאם; פיתאום')
    end

    context 'when alternate_titles has some other (user-provided) names' do
      it 'preserves existing alternate_titles' do
        collection.update_column(:alternate_titles, 'משהו אחר')
        collection.update_alternate_titles
        expect(collection.alternate_titles).to eq('משהו אחר; פתאם; פיתאום')
      end
    end
  end

  describe 'before_save callbacks' do
    let(:collection) { build(:collection, title: 'מִבְחַר שִירִים') }

    describe 'update_alternate_titles callback' do
      it 'is triggered when title changes on create' do
        expect(collection).to receive(:update_alternate_titles)
        collection.save!
      end

      it 'is not triggered when title does not change' do
        collection.save!
        collection.reload
        expect(collection).not_to receive(:update_alternate_titles)
        collection.update!(subtitle: 'new subtitle')
      end

      it 'is triggered when title changes on update' do
        collection.save!
        collection.reload
        expect(collection).to receive(:update_alternate_titles)
        collection.update!(title: 'כותר חדש')
      end
    end
  end

  describe '.uncollected_more_than_once' do
    it 'returns items that appear in more than one uncollected collection' do
      # Create uncollected collections (bypass validation using update_column)
      uncollected1 = create(:collection, collection_type: :other)
      uncollected1.update_column(:collection_type, Collection.collection_types[:uncollected])

      uncollected2 = create(:collection, collection_type: :other)
      uncollected2.update_column(:collection_type, Collection.collection_types[:uncollected])

      # Create manifestations
      m1 = create(:manifestation)
      m2 = create(:manifestation)
      m3 = create(:manifestation)

      # Add m1 to both uncollected collections (should be returned)
      create(:collection_item, collection: uncollected1, item: m1, seqno: 1)
      create(:collection_item, collection: uncollected2, item: m1, seqno: 1)

      # Add m2 to only one uncollected collection (should NOT be returned)
      create(:collection_item, collection: uncollected1, item: m2, seqno: 2)

      # Add m3 to both uncollected collections (should be returned)
      create(:collection_item, collection: uncollected1, item: m3, seqno: 3)
      create(:collection_item, collection: uncollected2, item: m3, seqno: 2)

      result = described_class.uncollected_more_than_once
      expect(result).to contain_exactly(m1, m3)
    end

    it 'ignores items in non-uncollected collections' do
      # Create uncollected collections
      uncollected1 = create(:collection, collection_type: :other)
      uncollected1.update_column(:collection_type, Collection.collection_types[:uncollected])

      uncollected2 = create(:collection, collection_type: :other)
      uncollected2.update_column(:collection_type, Collection.collection_types[:uncollected])

      # Create a regular collection
      regular = create(:collection, collection_type: :series)

      # Create a manifestation
      m1 = create(:manifestation)

      # Add m1 to one uncollected and one regular collection
      # (should NOT be returned - must be in 2+ uncollected)
      create(:collection_item, collection: uncollected1, item: m1, seqno: 1)
      create(:collection_item, collection: regular, item: m1, seqno: 1)

      result = described_class.uncollected_more_than_once
      expect(result).to be_empty
    end

    it 'excludes placeholder items (nil item_id)' do
      # Create uncollected collections
      uncollected1 = create(:collection, collection_type: :other)
      uncollected1.update_column(:collection_type, Collection.collection_types[:uncollected])

      uncollected2 = create(:collection, collection_type: :other)
      uncollected2.update_column(:collection_type, Collection.collection_types[:uncollected])

      # Create placeholder items (item: nil)
      create(:collection_item, collection: uncollected1, item: nil, alt_title: 'Placeholder 1', seqno: 1)
      create(:collection_item, collection: uncollected2, item: nil, alt_title: 'Placeholder 2', seqno: 1)

      result = described_class.uncollected_more_than_once
      expect(result).to be_empty
    end

    it 'works with different item types (Manifestation, Work, Person)' do
      # Create uncollected collections
      uncollected1 = create(:collection, collection_type: :other)
      uncollected1.update_column(:collection_type, Collection.collection_types[:uncollected])

      uncollected2 = create(:collection, collection_type: :other)
      uncollected2.update_column(:collection_type, Collection.collection_types[:uncollected])

      # Create different types of items
      m1 = create(:manifestation)
      p1 = create(:person)

      # Add same items to both uncollected collections
      create(:collection_item, collection: uncollected1, item: m1, seqno: 1)
      create(:collection_item, collection: uncollected2, item: m1, seqno: 1)
      create(:collection_item, collection: uncollected1, item: p1, seqno: 2)
      create(:collection_item, collection: uncollected2, item: p1, seqno: 2)

      result = described_class.uncollected_more_than_once
      expect(result).to contain_exactly(m1, p1)
    end

    it 'returns empty array when no items are in multiple uncollected collections' do
      # Create uncollected collections
      uncollected1 = create(:collection, collection_type: :other)
      uncollected1.update_column(:collection_type, Collection.collection_types[:uncollected])

      uncollected2 = create(:collection, collection_type: :other)
      uncollected2.update_column(:collection_type, Collection.collection_types[:uncollected])

      # Create manifestations, each in only one collection
      m1 = create(:manifestation)
      m2 = create(:manifestation)
      create(:collection_item, collection: uncollected1, item: m1, seqno: 1)
      create(:collection_item, collection: uncollected2, item: m2, seqno: 1)

      result = described_class.uncollected_more_than_once
      expect(result).to be_empty
    end
  end

  describe '#editors' do
    let(:collection) { create(:collection) }
    let(:parent_collection) { create(:collection) }
    let(:editor1) { create(:authority) }
    let(:editor2) { create(:authority) }

    context 'when collection has its own editors' do
      before do
        create(:involved_authority, item: collection, authority: editor1, role: 'editor')
      end

      it 'returns the collection editors' do
        expect(collection.editors).to contain_exactly(editor1)
      end

      it 'returns the collection editors when immediate_only is true' do
        expect(collection.editors(true)).to contain_exactly(editor1)
      end
    end

    context 'when collection has no editors but parent has editors' do
      before do
        create(:collection_item, collection: parent_collection, item: collection)
        create(:involved_authority, item: parent_collection, authority: editor2, role: 'editor')
      end

      it 'inherits editors from parent collection by default' do
        expect(collection.editors).to contain_exactly(editor2)
      end

      it 'returns empty array when immediate_only is true' do
        expect(collection.editors(true)).to eq([])
      end
    end

    context 'when collection has editors and parent also has editors' do
      before do
        create(:collection_item, collection: parent_collection, item: collection)
        create(:involved_authority, item: collection, authority: editor1, role: 'editor')
        create(:involved_authority, item: parent_collection, authority: editor2, role: 'editor')
      end

      it 'returns only the collection own editors, not parent editors' do
        expect(collection.editors).to contain_exactly(editor1)
      end

      it 'returns only the collection own editors when immediate_only is true' do
        expect(collection.editors(true)).to contain_exactly(editor1)
      end
    end
  end

  describe '#editors_string' do
    let(:collection) { create(:collection) }
    let(:parent_collection) { create(:collection) }
    let(:editor1) { create(:authority, name: 'Editor One') }
    let(:editor2) { create(:authority, name: 'Editor Two') }

    context 'when collection has its own editors' do
      before do
        create(:involved_authority, item: collection, authority: editor1, role: 'editor')
      end

      it 'returns the editors names as a string' do
        expect(collection.editors_string).to eq('Editor One')
      end

      it 'returns the editors names when immediate_only is true' do
        expect(collection.editors_string(true)).to eq('Editor One')
      end
    end

    context 'when collection has no editors but parent has editors' do
      before do
        create(:collection_item, collection: parent_collection, item: collection)
        create(:involved_authority, item: parent_collection, authority: editor2, role: 'editor')
      end

      it 'inherits editors string from parent collection by default' do
        expect(collection.editors_string).to eq('Editor Two')
      end

      it 'returns nil when immediate_only is true' do
        expect(collection.editors_string(true)).to be_nil
      end
    end

    context 'when collection has multiple editors' do
      let(:editor3) { create(:authority, name: 'Editor Three') }

      before do
        create(:involved_authority, item: collection, authority: editor1, role: 'editor')
        create(:involved_authority, item: collection, authority: editor3, role: 'editor')
      end

      it 'returns editors joined with comma and space' do
        expect(collection.editors_string).to eq('Editor One, Editor Three')
      end
    end
  end

  describe '#parent_volume_or_isssue' do
    it 'returns nil when the collection has no parent' do
      c = create(:collection, collection_type: :series)
      expect(c.parent_volume_or_isssue).to be_nil
    end

    it 'returns the direct parent when it is a volume' do
      volume = create(:collection, collection_type: :volume)
      series = create(:collection, collection_type: :series)
      create(:collection_item, collection: volume, item: series)
      expect(series.parent_volume_or_isssue).to eq(volume)
    end

    it 'traverses multiple levels of nesting to find an ancestor volume' do
      volume = create(:collection, collection_type: :volume)
      series_outer = create(:collection, collection_type: :series)
      series_inner = create(:collection, collection_type: :series)
      create(:collection_item, collection: volume, item: series_outer)
      create(:collection_item, collection: series_outer, item: series_inner)
      expect(series_inner.parent_volume_or_isssue).to eq(volume)
    end

    it 'returns nil when there is no volume anywhere in the parent tree' do
      series_outer = create(:collection, collection_type: :series)
      series_inner = create(:collection, collection_type: :series)
      create(:collection_item, collection: series_outer, item: series_inner)
      expect(series_inner.parent_volume_or_isssue).to be_nil
    end

    it 'prefers a direct parent volume over a more distant one on another branch' do
      # series_inner has two parents: volume_direct (level 1) and series_outer which leads to volume_deep (level 2)
      volume_direct = create(:collection, collection_type: :volume)
      volume_deep = create(:collection, collection_type: :volume)
      series_outer = create(:collection, collection_type: :series)
      series_inner = create(:collection, collection_type: :series)
      create(:collection_item, collection: volume_direct, item: series_inner)
      create(:collection_item, collection: series_outer, item: series_inner)
      create(:collection_item, collection: volume_deep, item: series_outer)
      expect(series_inner.parent_volume_or_isssue).to eq(volume_direct)
    end
  end

  describe '#toc_html' do
    let(:issue) { create(:collection, collection_type: :periodical_issue) }
    let(:manifestation) { create(:manifestation) }

    before do
      create(:collection_item, collection: issue, item: manifestation, seqno: 1)
    end

    it 'generates plain text TOC without url_builder' do
      html = issue.toc_html
      expect(html).to include(manifestation.title)
      expect(html).not_to include('<a href=')
    end

    it 'generates linked TOC when url_builder is provided' do
      url_builder = ->(item) { "/manifestations/#{item.id}" }
      html = issue.toc_html(url_builder: url_builder)
      expect(html).to include("<a href=\"/manifestations/#{manifestation.id}\"")
      expect(html).to include(manifestation.title)
    end

    it 'skips items with no content' do
      create(:collection_item, collection: issue, item: nil, alt_title: nil, markdown: nil, seqno: 2)
      url_builder = ->(item) { "/manifestations/#{item.id}" }
      html = issue.toc_html(url_builder: url_builder)
      doc = Nokogiri::HTML.fragment(html)
      expect(doc.css('li').count).to eq(1)
      expect(doc.css("a[href=\"/manifestations/#{manifestation.id}\"]").count).to eq(1)
    end
  end

  describe '#invalidate_cached_credits!' do
    let(:collection) { create(:collection, collection_type: :volume) }
    let(:authority) { create(:authority) }

    before do
      collection.update!(cached_credits: 'some credits')
      authority.update!(cached_credits: 'some credits')
      create(:involved_authority, item: collection, authority: authority, role: 'editor')
    end

    it 'invalidates the cached credits of the collection itself' do
      collection.invalidate_cached_credits!
      expect(collection.reload.cached_credits).to be_nil
    end

    it 'invalidates the cached credits of every involved authority' do
      collection.invalidate_cached_credits!
      expect(authority.reload.cached_credits).to be_nil
    end

    context 'when the collection has parent collections' do
      let(:parent1) { create(:collection, collection_type: :volume_series) }
      let(:parent2) { create(:collection, collection_type: :other) }

      before do
        parent1.update!(cached_credits: 'parent 1 credits')
        parent2.update!(cached_credits: 'parent 2 credits')
        create(:collection_item, collection: parent1, item: collection)
        create(:collection_item, collection: parent2, item: collection)
      end

      it 'invalidates the cached credits of all parent collections' do
        collection.invalidate_cached_credits!
        expect(parent1.reload.cached_credits).to be_nil
        expect(parent2.reload.cached_credits).to be_nil
      end
    end

    context 'when parent collections have parent collections themselves (recursive invalidation)' do
      let(:parent) { create(:collection, collection_type: :volume_series) }
      let(:grandparent) { create(:collection, collection_type: :other) }

      before do
        parent.update!(cached_credits: 'parent credits')
        grandparent.update!(cached_credits: 'grandparent credits')
        create(:collection_item, collection: parent, item: collection)
        create(:collection_item, collection: grandparent, item: parent)
      end

      it 'recursively invalidates the cached credits of all ancestor collections' do
        collection.invalidate_cached_credits!
        expect(parent.reload.cached_credits).to be_nil
        expect(grandparent.reload.cached_credits).to be_nil
      end
    end
  end
end
