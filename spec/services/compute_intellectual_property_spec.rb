# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ComputeIntellectualProperty do
  describe '#call' do
    context 'with no authority IDs' do
      it 'returns unknown' do
        expect(described_class.call([])).to eq(:unknown)
      end

      it 'returns unknown for nil' do
        expect(described_class.call(nil)).to eq(:unknown)
      end
    end

    context 'with all public_domain authorities' do
      let!(:author1) { create(:authority, intellectual_property: :public_domain) }
      let!(:author2) { create(:authority, intellectual_property: :public_domain) }

      it 'returns public_domain' do
        expect(described_class.call([author1.id, author2.id])).to eq(:public_domain)
      end
    end

    context 'with mixed authorities including copyrighted' do
      let!(:author1) { create(:authority, intellectual_property: :public_domain) }
      let!(:author2) { create(:authority, intellectual_property: :copyrighted) }

      it 'returns copyrighted when any authority is copyrighted' do
        expect(described_class.call([author1.id, author2.id])).to eq(:copyrighted)
      end
    end

    context 'with permission_for_all authority' do
      let!(:author1) { create(:authority, intellectual_property: :public_domain) }
      let!(:author2) { create(:authority, intellectual_property: :permission_for_all) }

      it 'returns by_permission' do
        expect(described_class.call([author1.id, author2.id])).to eq(:by_permission)
      end
    end

    context 'with orphan authority' do
      let!(:author1) { create(:authority, intellectual_property: :public_domain) }
      let!(:author2) { create(:authority, intellectual_property: :orphan) }

      it 'returns orphan' do
        expect(described_class.call([author1.id, author2.id])).to eq(:orphan)
      end
    end

    context 'with multiple non-public-domain authorities' do
      let!(:author1) { create(:authority, intellectual_property: :copyrighted) }
      let!(:author2) { create(:authority, intellectual_property: :permission_for_all) }

      it 'returns copyrighted when copyrighted is present with permission' do
        expect(described_class.call([author1.id, author2.id])).to eq(:copyrighted)
      end
    end

    context 'with three authors including translator' do
      let!(:author) { create(:authority, intellectual_property: :public_domain) }
      let!(:translator) { create(:authority, intellectual_property: :copyrighted) }
      let!(:editor) { create(:authority, intellectual_property: :public_domain) }

      it 'returns copyrighted when translator is copyrighted' do
        expect(described_class.call([author.id, translator.id, editor.id])).to eq(:copyrighted)
      end
    end

    context 'with single copyrighted author' do
      let!(:author) { create(:authority, intellectual_property: :copyrighted) }

      it 'returns copyrighted' do
        expect(described_class.call([author.id])).to eq(:copyrighted)
      end
    end

    context 'with single public_domain author' do
      let!(:author) { create(:authority, intellectual_property: :public_domain) }

      it 'returns public_domain' do
        expect(described_class.call([author.id])).to eq(:public_domain)
      end
    end

    context 'with unknown authority' do
      let!(:author) { create(:authority, intellectual_property: :unknown) }

      it 'returns unknown' do
        expect(described_class.call([author.id])).to eq(:unknown)
      end
    end

    context 'with permission_for_selected authority' do
      let!(:author1) { create(:authority, intellectual_property: :public_domain) }
      let!(:author2) { create(:authority, intellectual_property: :permission_for_selected) }

      it 'returns by_permission' do
        expect(described_class.call([author1.id, author2.id])).to eq(:by_permission)
      end
    end
  end
end
