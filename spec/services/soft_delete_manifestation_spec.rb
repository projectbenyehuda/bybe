# frozen_string_literal: true

require 'rails_helper'

describe SoftDeleteManifestation do
  subject(:result) { described_class.call(manifestation, target) }

  let(:manifestation) { create(:manifestation) }
  let(:target) { create(:manifestation) }

  describe 'validation' do
    context 'when the target is nil' do
      let(:target) { nil }

      it 'fails and leaves the manifestation alone' do
        expect(result).to eq(success: false, error: I18n.t(:manifestation_not_found))
        expect(manifestation.reload).to be_published
        expect(manifestation.soft_redirect).to be_nil
      end
    end

    context 'when the target is the manifestation itself' do
      let(:target) { manifestation }

      it 'fails' do
        expect(result).to eq(success: false, error: I18n.t(:soft_delete_same_manifestation))
        expect(manifestation.reload).to be_published
      end
    end

    context 'when the target is itself deprecated' do
      let(:target) { create(:manifestation, status: :deprecated) }

      it 'fails with the deprecated-target error rather than the unpublished one' do
        expect(result).to eq(success: false, error: I18n.t(:soft_delete_target_deprecated))
        expect(manifestation.reload).to be_published
      end
    end

    # A reader sent to one of these would be turned away by set_manifestation, so the redirect
    # would be useless to exactly the readers it exists for.
    %i(unpublished nonpd).each do |status|
      context "when the target is #{status}" do
        let(:target) { create(:manifestation, status: status) }

        it 'fails' do
          expect(result).to eq(success: false, error: I18n.t(:soft_delete_target_not_published))
          expect(manifestation.reload).to be_published
        end
      end
    end
  end

  describe 'the soft deletion itself' do
    it 'marks the manifestation deprecated and records the redirect target' do
      expect(result).to eq(success: true)
      manifestation.reload
      expect(manifestation).to be_deprecated
      expect(manifestation.soft_redirect).to eq(target.id)
      expect(manifestation.soft_redirect_target).to eq(target)
    end

    it 'leaves the target untouched' do
      result
      expect(target.reload).to be_published
      expect(target.soft_redirect).to be_nil
    end

    context 'when the manifestation was already soft-deleted' do
      let(:other) { create(:manifestation) }

      it 'lets an editor correct the redirect target' do
        described_class.call(manifestation, other)
        expect(result).to eq(success: true)
        expect(manifestation.reload.soft_redirect).to eq(target.id)
      end
    end
  end

  describe 'collection items' do
    let(:collection) { create(:collection) }

    before { collection.collection_items.create!(item: manifestation, seqno: 1) }

    it 'repoints them at the target' do
      expect { result }.not_to change(CollectionItem, :count)
      expect(collection.reload.collection_items.map(&:item)).to eq([target])
    end

    it 'preserves the position in the collection' do
      collection.collection_items.create!(item: create(:manifestation), seqno: 2)
      CollectionItem.find_by(item: manifestation).update!(seqno: 7)
      result
      expect(collection.collection_items.find_by(item: target).seqno).to eq(7)
    end

    context 'when the collection already holds the target' do
      before { collection.collection_items.create!(item: target, seqno: 2) }

      it 'drops the redundant item rather than listing the target twice' do
        expect { result }.to change(CollectionItem, :count).by(-1)
        expect(collection.reload.collection_items.map(&:item)).to eq([target])
      end
    end

    context 'when the manifestation sits in several collections' do
      let(:other_collection) { create(:collection) }

      before { other_collection.collection_items.create!(item: manifestation, seqno: 1) }

      it 'amends every one of them' do
        result
        expect(collection.reload.collection_items.map(&:item)).to eq([target])
        expect(other_collection.reload.collection_items.map(&:item)).to eq([target])
      end
    end
  end

  describe 'anthology texts' do
    let(:anthology) { create(:anthology, manifestations: [manifestation]) }

    before { anthology }

    it 'repoints them at the target' do
      expect { result }.not_to change(AnthologyText, :count)
      expect(anthology.texts.reload.map(&:manifestation)).to eq([target])
    end

    context 'when the anthology already holds the target' do
      # anthology_texts carries a unique index on (anthology_id, manifestation_id), so repointing
      # here would not merely duplicate -- it would raise.
      before { create(:anthology_text, anthology: anthology, manifestation: target) }

      it 'drops the redundant text' do
        expect { result }.to change(AnthologyText, :count).by(-1)
        expect(anthology.texts.reload.map(&:manifestation)).to eq([target])
      end
    end
  end

  describe 'taggings' do
    let(:tag) { create(:tag) }

    before { create(:tagging, taggable: manifestation, tag: tag, status: :approved) }

    it 'repoints them at the target' do
      expect { result }.not_to change(Tagging, :count)
      expect(target.reload.taggings.map(&:tag)).to eq([tag])
      expect(manifestation.reload.taggings).to be_empty
    end

    context 'when the target already carries the same tag' do
      before { create(:tagging, taggable: target, tag: tag, status: :approved) }

      it 'drops the redundant tagging' do
        expect { result }.to change(Tagging, :count).by(-1)
        expect(target.reload.taggings.count).to eq(1)
      end
    end
  end

  describe 'recommendations' do
    let(:user) { create(:user) }

    before { create(:recommendation, manifestation: manifestation, user: user) }

    it 'repoints them at the target' do
      expect { result }.not_to change(Recommendation, :count)
      expect(target.reload.recommendations.map(&:user)).to eq([user])
    end

    context 'when the same user already recommended the target' do
      before { create(:recommendation, manifestation: target, user: user) }

      it 'drops the redundant recommendation' do
        expect { result }.to change(Recommendation, :count).by(-1)
        expect(target.reload.recommendations.count).to eq(1)
      end
    end
  end

  describe 'external links' do
    before { create(:external_link, linkable: manifestation, url: 'https://example.com/a') }

    it 'repoints them at the target' do
      expect { result }.not_to change(ExternalLink, :count)
      expect(target.reload.external_links.map(&:url)).to eq(['https://example.com/a'])
    end

    context 'when the target already links to the same url' do
      before { create(:external_link, linkable: target, url: 'https://example.com/a') }

      it 'drops the redundant link' do
        expect { result }.to change(ExternalLink, :count).by(-1)
        expect(target.reload.external_links.count).to eq(1)
      end
    end
  end

  describe 'atomicity' do
    let(:collection) { create(:collection) }

    before do
      collection.collection_items.create!(item: manifestation, seqno: 1)
      allow_any_instance_of(Manifestation).to receive(:update!).and_raise('boom') # rubocop:disable RSpec/AnyInstance
    end

    it 'rolls the re-association back when marking the manifestation fails' do
      expect(result[:success]).to be false
      expect(collection.reload.collection_items.map(&:item)).to eq([manifestation])
      expect(manifestation.reload).to be_published
    end
  end
end
