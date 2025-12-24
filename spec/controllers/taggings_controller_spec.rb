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

  describe '#browse' do
    subject { get :browse, params: params }

    let(:params) { {} }

    context 'with no tags' do
      it { is_expected.to be_successful }

      it 'assigns empty tags' do
        subject
        expect(assigns(:tags)).to be_empty
      end
    end

    context 'with approved tags' do
      let!(:tag1) { create(:tag, name: 'Alpha', status: :approved) }
      let!(:tag2) { create(:tag, name: 'Beta', status: :approved) }
      let!(:pending_tag) { create(:tag, name: 'Pending', status: :pending) }

      it { is_expected.to be_successful }

      it 'only includes approved tags' do
        subject
        expect(assigns(:tags)).to include(tag1, tag2)
        expect(assigns(:tags)).not_to include(pending_tag)
      end

      it 'sorts alphabetically by default' do
        subject
        expect(assigns(:tags).to_a).to eq([tag1, tag2])
      end

      context 'when sorting by popularity' do
        let(:params) { { sort_by: 'popularity' } }

        before do
          tag1.update!(approved_taggings_count: 5)
          tag2.update!(approved_taggings_count: 10)
        end

        it 'sorts by taggings count descending' do
          subject
          expect(assigns(:tags).to_a).to eq([tag2, tag1])
        end
      end

      context 'with pagination' do
        before do
          # Create enough tags to trigger pagination (assuming default is 25 per page)
          30.times do |i|
            create(:tag, name: "Tag#{i.to_s.rjust(3, '0')}", status: :approved)
          end
        end

        it 'paginates results' do
          subject
          expect(assigns(:tags).count).to be <= 25
        end

        context 'when requesting page 2' do
          let(:params) { { page: 2 } }

          it 'returns second page of results' do
            subject
            expect(assigns(:tags).current_page).to eq(2)
          end
        end
      end
    end
  end
end
