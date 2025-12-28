# frozen_string_literal: true

require 'rails_helper'

describe AnthologyText do
  describe 'validation' do
    describe 'manifestation_id uniqueness' do
      subject(:result) { anthology_text.valid? }

      let!(:anthology_text) do
        build(:anthology_text, anthology: anthology, manifestation: test_manifestation)
      end

      let(:anthology) { create(:anthology) }
      let(:other_anthology) { create(:anthology) }
      let(:other_manifestation) { create(:manifestation) }

      before do
        # same anthology, different manifestation
        create(:anthology_text, anthology: anthology, manifestation: other_manifestation)
        # different anthology, same manifestation
        create(:anthology_text, anthology: other_anthology, manifestation: test_manifestation)
      end

      context 'when no record with this manifestation exists in the anthology' do
        let(:test_manifestation) { create(:manifestation) }

        it { is_expected.to be_truthy }
      end

      context 'when anthology already has this manifestation' do
        let(:test_manifestation) { other_manifestation }

        it 'generates validation error' do
          expect(result).to be false
          expect(anthology_text.errors[:manifestation]).to include(
            I18n.t('activerecord.errors.models.anthology_text.attributes.manifestation.taken')
          )
        end
      end

      context 'when manifestation_id is nil' do
        let(:test_manifestation) { nil }

        before do
          # we should be able to have multiple anthology_texts with nil manifestation in the same anthology
          create(:anthology_text, anthology: anthology, manifestation: nil)
        end

        it { is_expected.to be_truthy }
      end
    end
  end
end
