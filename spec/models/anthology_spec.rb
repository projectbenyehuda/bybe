require 'rails_helper'

describe Anthology do
  describe 'validation' do
    describe 'title uniqueness' do
      subject(:result) { record.valid? }
      let(:user) { create(:user) }
      let(:other_user) { create(:user) }

      let(:new_title) { 'New Title' }
      let(:existing_title) { 'Existing Title' }

      before do
        create(:anthology, user: user, title: existing_title)
        # this anthology belongs to different user, so should not be taken in account
        create(:anthology, user: other_user, title: new_title)
      end

      context 'when this is a new record' do
        let(:record) { build(:anthology, user: user, title: anthology_title) }

        context 'when no records with this name exists for user' do
          let(:anthology_title) { new_title }
          it { is_expected.to be_truthy }
        end

        context 'when user already has record with given title' do
          let(:anthology_title) { existing_title }
          it 'generates validation error' do
            expect(result).to be false
            expect(record.errors[:title]).to include(
              I18n.t('activerecord.errors.models.anthology.attributes.title.taken')
            )
          end
        end
      end

      context 'when this is an existing record' do
        let(:record) do
          # record had unique title and now it is being updated
          rec = create(:anthology, user: user, title: 'some title')
          rec.title = anthology_title
          rec
        end

        context 'when no records with this name exists for user' do
          let(:anthology_title) { new_title }
          it { is_expected.to be_truthy }
        end

        context 'when user already has record with given title' do
          let(:anthology_title) { existing_title }
          it 'generates validation error' do
            expect(result).to be false
            expect(record.errors[:title]).to include(
              I18n.t('activerecord.errors.models.anthology.attributes.title.taken')
            )
          end
        end
      end
    end
  end

  describe '#fresh_downloadable_for' do
    let(:anthology) { create(:anthology) }

    context 'when downloadable has attached file' do
      let!(:downloadable) { create(:downloadable, :with_file, object: anthology, doctype: :pdf) }

      it 'returns the downloadable' do
        expect(anthology.fresh_downloadable_for('pdf')).to eq downloadable
      end
    end

    context 'when downloadable exists but has no attached file' do
      let!(:downloadable) { create(:downloadable, :without_file, object: anthology, doctype: :pdf) }

      it 'returns nil' do
        expect(anthology.fresh_downloadable_for('pdf')).to be_nil
      end
    end

    context 'when no downloadable exists' do
      it 'returns nil' do
        expect(anthology.fresh_downloadable_for('pdf')).to be_nil
      end
    end
  end
end