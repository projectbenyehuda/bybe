require 'rails_helper'

describe BibController do
  let(:user) { create(:user, :bib_workshop) }
  before do
    session[:user_id] = user.id
  end

  describe '#index' do
    subject { get :index, params: { authority_id: authority_id } }

    let(:publication) { create(:publication) }

    before do
      create_list(:publication, 5)
    end

    context 'when authority_id is not provided' do
      let(:authority_id) { nil }

      it { is_expected.to be_successful }
    end

    context 'when authority_id is provided' do
      let(:authority_id) { publication.authority.id }

      it { is_expected.to be_successful }
    end
  end

  describe '#shopping' do
    subject { get :shopping, params: { source_id: source.id, pd: pd, nonpd: nonpd, unique: unique } }

    let(:pd) { nil }
    let(:nonpd) { nil }
    let(:unique) { nil }
    let(:source) { create(:bib_source) }

    context 'when no additional params are provided' do
      it { is_expected.to be_successful }
    end

    context 'when unique public_domain' do
      let(:pd) { 1 }
      let(:unique) { 1 }

      it { is_expected.to be_successful }
    end

    context 'when non-unique public_domain' do
      let(:pd) { 1 }
      let(:unique) { 0 }

      it { is_expected.to be_successful }
    end

    context 'when unique' do
      let(:pd) { 0 }
      let(:unique) { 1 }

      it { is_expected.to be_successful }
    end

    context 'when non-public domain unique' do
      let(:nonpd) { 1 }
      let(:unique) { 1 }

      it { is_expected.to be_successful }
    end

    context 'when non-public domain non-unique' do
      let(:nonpd) { 1 }
      let(:unique) { 0 }

      it { is_expected.to be_successful }
    end
  end

  describe '#authority' do
    subject { get :authority, params: { authority_id: authority.id } }

    let!(:authority) { create(:authority, bib_done: false) }
    let!(:pubs) { create(:publication, authority: authority) }

    it { is_expected.to be_successful }
  end

  describe '#make_author_page' do
    subject { post :make_author_page, params: { authority_id: authority.id } }

    let!(:authority) { create(:authority, bib_done: false) }
    let!(:pubs) { create(:publication, authority: authority) }

    it { is_expected.to be_successful }
  end

  describe '#pubs_by_authority' do
    subject(:call) { get :pubs_by_authority, params: { authority_id: authority_id, q: query } }

    let(:query) { nil }

    context 'when authority id is not provided' do
      let(:authority_id) { nil }

      it { is_expected.to be_successful }
    end

    context 'when authority id is provided' do
      let(:authority) { create(:authority) }
      let(:authority_id) { authority.id }

      it { is_expected.to be_successful }
    end
  end

  describe '#pubs_maybe_done' do
    subject(:request) { get :pubs_maybe_done }

    let!(:original_maybe_done_pub) { create(:publication, :pubs_maybe_done, title: 'original title') }
    let!(:original_manifestation) do
      create(
        :manifestation,
        title: "#{original_maybe_done_pub.title} manifestation",
        author: original_maybe_done_pub.authority
      )
    end

    let!(:translated_maybe_done_pub) { create(:publication, :pubs_maybe_done, title: 'translated title') }
    let!(:translated_manifestation_1) do
      create(
        :manifestation,
        title: "#{translated_maybe_done_pub.title} manifestation 1",
        orig_lang: 'ru',
        translator: translated_maybe_done_pub.authority
      )
    end
    let!(:translated_manifestation_2) do
      create(
        :manifestation,
        title: "#{translated_maybe_done_pub.title} manifestation 2",
        orig_lang: 'ru',
        translator: translated_maybe_done_pub.authority
      )
    end

    let!(:other_pubs) { create_list(:publication, 2) }

    it 'renders all publications where pubs_maybe_done list item present' do
      expect(request).to be_successful
      expect(assigns(:pubs)).to match_array [
        [original_maybe_done_pub, [original_manifestation]],
        [translated_maybe_done_pub, [translated_manifestation_1, translated_manifestation_2]]
      ]
    end

    context 'when a publication in the list has no matching manifestation titles' do
      let!(:unmatched_pub) { create(:publication, :pubs_maybe_done, title: 'completely unique title') }

      it 'excludes the publication from the results' do
        expect(request).to be_successful
        pub_items = assigns(:pubs).map(&:first)
        expect(pub_items).not_to include(unmatched_pub)
      end
    end
  end
end
