# frozen_string_literal: true

require 'rails_helper'

describe LexPersonWork do
  describe '#comment' do
    # Regression: the column was varchar(255), so a long bibliographic note was silently
    # truncated (or rejected in strict mode) on save. It is now varchar(4096).
    it 'persists a comment of 4096 characters without truncation' do
      long_comment = 'א' * 4096
      work = create(:lex_person_work, comment: long_comment)

      expect(work.reload.comment).to eq long_comment
    end
  end

  describe 'linking the chosen collection to the chosen publication' do
    subject(:save_work) { work.save }

    let(:publication) { create(:publication) }
    let(:work) { build(:lex_person_work, publication: publication, collection: collection) }

    context 'when the collection is not linked to any publication' do
      let(:collection) { create(:collection, publication: nil) }

      it 'links the collection to the publication instead of failing validation' do
        expect(save_work).to be true
        expect(collection.reload.publication).to eq publication
        expect(work.reload).to have_attributes(publication: publication, collection: collection)
      end
    end

    context 'when the collection is already linked to the chosen publication' do
      let(:collection) { create(:collection, publication: publication) }

      it 'saves without touching the collection' do
        expect { save_work }.not_to(change { collection.reload.updated_at })
        expect(work.reload).to have_attributes(publication: publication, collection: collection)
      end
    end

    context 'when the collection belongs to a different publication' do
      let(:other_publication) { create(:publication) }
      let(:collection) { create(:collection, publication: other_publication) }

      it 'is rejected, leaving the other publication its volume' do
        expect(save_work).to be false
        expect(work.errors[:collection]).to be_present
        expect(collection.reload.publication).to eq other_publication
      end
    end

    context 'when the work fails validation for an unrelated reason' do
      let(:collection) { create(:collection, publication: nil) }
      let(:work) do
        build(:lex_person_work, title: '', publication: publication, collection: collection)
      end

      it 'does not link the collection' do
        expect(save_work).to be false
        expect(collection.reload.publication).to be_nil
      end
    end
  end
end
