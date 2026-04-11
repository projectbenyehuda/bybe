# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedSelection do
  let(:owner) { create(:user, editor: true) }
  let(:other_user) { create(:user, editor: true) }

  def make_selection(user:, shared: false, delete_after: nil)
    attrs = { name: 'Test', user: user, shared: shared }
    attrs[:delete_after] = delete_after || 90.days.from_now.to_date
    SavedSelection.create!(**attrs)
  end

  describe 'validations' do
    it 'is valid with a name and user' do
      sel = described_class.new(name: 'My Selection', user: owner, delete_after: 90.days.from_now.to_date)
      expect(sel).to be_valid
    end

    it 'is invalid without a name' do
      sel = described_class.new(user: owner, delete_after: 90.days.from_now.to_date)
      expect(sel).not_to be_valid
      expect(sel.errors[:name]).to be_present
    end
  end

  describe '#delete_after default' do
    it 'defaults to 90 days from today when not set' do
      sel = described_class.create!(name: 'Auto Expire', user: owner)
      expect(sel.delete_after).to eq(90.days.from_now.to_date)
    end

    it 'does not override an explicitly set delete_after' do
      custom_date = 30.days.from_now.to_date
      sel = described_class.create!(name: 'Custom Expire', user: owner, delete_after: custom_date)
      expect(sel.delete_after).to eq(custom_date)
    end
  end

  describe '.active scope' do
    it 'includes selections with delete_after >= today' do
      active = make_selection(user: owner, delete_after: Time.zone.today)
      expect(described_class.active).to include(active)
    end

    it 'excludes selections with delete_after < today' do
      expired = make_selection(user: owner, delete_after: Time.zone.yesterday)
      expect(described_class.active).not_to include(expired)
    end
  end

  describe '.visible_to scope' do
    context 'with a private (unshared) selection owned by owner' do
      let!(:private_sel) { make_selection(user: owner, shared: false) }

      it 'is visible to the owner' do
        expect(described_class.visible_to(owner)).to include(private_sel)
      end

      it 'is NOT visible to another user' do
        expect(described_class.visible_to(other_user)).not_to include(private_sel)
      end
    end

    context 'with a shared selection owned by owner' do
      let!(:shared_sel) { make_selection(user: owner, shared: true) }

      it 'is visible to the owner' do
        expect(described_class.visible_to(owner)).to include(shared_sel)
      end

      it 'is visible to another user' do
        expect(described_class.visible_to(other_user)).to include(shared_sel)
      end
    end

    context 'with an expired selection' do
      let!(:expired_private) { make_selection(user: owner, shared: false, delete_after: Time.zone.yesterday) }
      let!(:expired_shared)  { make_selection(user: owner, shared: true,  delete_after: Time.zone.yesterday) }

      it 'excludes expired private selection from owner' do
        expect(described_class.visible_to(owner)).not_to include(expired_private)
      end

      it 'excludes expired shared selection from any user' do
        expect(described_class.visible_to(other_user)).not_to include(expired_shared)
      end
    end

    context 'with a mix of active and active-shared selections' do
      let!(:own_private)   { make_selection(user: owner,      shared: false) }
      let!(:own_shared)    { make_selection(user: owner,      shared: true) }
      let!(:other_private) { make_selection(user: other_user, shared: false) }
      let!(:other_shared)  { make_selection(user: other_user, shared: true) }

      it 'returns own private, own shared, and other shared — but NOT other private' do
        visible = described_class.visible_to(owner)
        expect(visible).to include(own_private, own_shared, other_shared)
        expect(visible).not_to include(other_private)
      end
    end
  end
end
