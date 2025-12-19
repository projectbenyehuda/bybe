# frozen_string_literal: true

require 'rails_helper'

describe TaggingsController do
  include_context 'when user logged in'

  describe '#add_tagging_popup' do
    subject { get :add_tagging_popup, params: { taggable_type: taggable.class.name, taggable_id: taggable.id } }

    context 'when Manifestation' do
      let(:taggable) { create(:manifestation) }

      it { is_expected.to be_successful }
    end

    context 'when Authority' do
      let(:taggable) { create(:authority) }

      it { is_expected.to be_successful }
    end

    context 'when Anthology' do
      let(:taggable) { create(:anthology, access: :pub) }

      it { is_expected.to be_successful }
    end
  end

  describe '#suggested' do
    subject { get :suggest, params: { author: authority.id } }

    let(:authority) { create(:authority) }

    let!(:first_tag) { create(:tag) }
    let!(:second_tag) { create(:tag) }
    let!(:not_used_tag) { create(:tag) }

    before do
      m = create(:manifestation, author: authority)
      create(:tagging, taggable: m, tag: first_tag)

      m = create(:manifestation, author: authority)
      create(:tagging, taggable: m, tag: second_tag)
    end

    it { is_expected.to be_successful }
  end

  describe '#pending_taggings_popup' do
    subject { get :pending_taggings_popup, params: { tag_id: tag } }

    let(:tag) { create(:tag) }
    let(:authority) { create(:authority) }
    let(:manifestation) { create(:manifestation) }

    let!(:authority_tagging) { create(:tagging, tag: tag, taggable: authority, status: :pending) }
    let!(:manifestation_tagging) { create(:tagging, tag: tag, taggable: manifestation, status: :pending) }

    it { is_expected.to be_successful }
  end
end
