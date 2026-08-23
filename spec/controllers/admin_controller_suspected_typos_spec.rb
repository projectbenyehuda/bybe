# frozen_string_literal: true

require 'rails_helper'

describe AdminController do
  include_context 'when editor logged in'

  let(:listkey) { Manifestation::SUSPECTED_TYPOS_LISTKEY }
  let(:okay_listkey) { Manifestation::SUSPECTED_TYPOS_OKAY_LISTKEY }
  let(:flagged) { create(:manifestation, genre: :poetry, markdown: "הוא נכנס לבי1ת ויצא\n") }

  describe '#suspected_typos' do
    subject(:call) { get :suspected_typos }

    before do
      create(:list_item, listkey: listkey, item: flagged, extra: 'digit_in_word:1')
      allow(Rails.cache).to receive(:write)
    end

    it 'lists the queued texts and caches the total for the dashboard' do
      expect(call).to be_successful
      expect(assigns(:list_items).map(&:item_id)).to eq [flagged.id]
      expect(Rails.cache).to have_received(:write).with('report_suspected_typos', 1)
    end

    it 'recomputes the individual findings for the texts on the page' do
      call
      expect(assigns(:findings)[flagged]).to contain_exactly(
        hash_including(type: :digit_in_word, line: 1)
      )
    end

    it 'renders the offending fragment and its label' do
      call
      expect(response.body).to include(I18n.t('suspected_typo_types.digit_in_word'))
      expect(response.body).to include('לבי1ת')
    end

    context 'when the queued manifestation has since been deleted' do
      before { flagged.destroy! }

      it 'still renders' do
        expect(call).to be_successful
      end
    end
  end

  describe '#mark_typos_as_okay' do
    subject(:call) { get :mark_typos_as_okay, params: { id: flagged.id } }

    let!(:queue_entry) { create(:list_item, listkey: listkey, item: flagged, extra: 'digit_in_word:1') }

    it 'whitelists the text and drops it from the queue' do
      expect(call).to have_http_status(:ok)
      expect(ListItem.exists?(listkey: okay_listkey, item: flagged)).to be true
      expect(ListItem.exists?(queue_entry.id)).to be false
    end

    it 'records the editor who made the call' do
      call
      expect(ListItem.find_by(listkey: okay_listkey, item: flagged).user).to eq current_user
    end

    it 'is idempotent' do
      call
      get :mark_typos_as_okay, params: { id: flagged.id }
      expect(ListItem.where(listkey: okay_listkey, item: flagged).count).to eq 1
    end

    context 'when the id does not exist' do
      subject(:call) { get :mark_typos_as_okay, params: { id: 0 } }

      it 'succeeds without creating anything' do
        expect { call }.not_to change(ListItem, :count)
        expect(call).to have_http_status(:ok)
      end
    end
  end
end
