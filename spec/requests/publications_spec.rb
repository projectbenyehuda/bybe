# frozen_string_literal: true

require 'rails_helper'

describe '/publications' do
  describe 'GET /publications/autocomplete_publication_title' do
    subject(:call) { get '/publications/autocomplete_publication_title?term=Test' }

    let!(:match_1) { create(:publication, title: 'Test Book One') }
    let!(:match_2) { create(:publication, title: 'Test Book Two') }
    let!(:no_match) { create(:publication, title: 'Different Book') }

    let(:expected_response) do
      [
        { 'id' => match_1.id.to_s, 'label' => match_1.title, 'value' => match_1.title },
        { 'id' => match_2.id.to_s, 'label' => match_2.title, 'value' => match_2.title }
      ]
    end

    context 'when user is not authenticated' do
      it { is_expected.to eq(302) }
    end

    context 'when user is authenticated and has editor permissions' do
      let(:user) { create(:user, editor: true) }

      before do
        controller = PublicationsController.new
        allow(controller).to receive(:current_user).and_return(user)
        allow(PublicationsController).to receive(:new).and_return(controller)
      end

      it 'returns a list of matching publications' do
        expect(call).to eq(200)
        expect(response.parsed_body).to match_array(expected_response)
      end
    end
  end

  describe 'GET /publications/autocomplete_authority_name' do
    subject(:call) { get '/publications/autocomplete_authority_name?term=Test' }

    let!(:match_1) { create(:authority, status: :published, name: 'Test Author One') }
    let!(:match_2) { create(:authority, status: :published, name: 'Test Author Two') }
    let!(:no_match) { create(:authority, status: :published, name: 'Different Author') }

    let(:expected_response) do
      [
        { 'id' => match_1.id.to_s, 'label' => match_1.name, 'value' => match_1.name },
        { 'id' => match_2.id.to_s, 'label' => match_2.name, 'value' => match_2.name }
      ]
    end

    context 'when user is not authenticated' do
      it { is_expected.to eq(302) }
    end

    context 'when user is authenticated and has editor permissions' do
      let(:user) { create(:user, editor: true) }

      before do
        controller = PublicationsController.new
        allow(controller).to receive(:current_user).and_return(user)
        allow(PublicationsController).to receive(:new).and_return(controller)
      end

      it 'returns a list of matching authorities' do
        expect(call).to eq(200)
        expect(response.parsed_body).to match_array(expected_response)
      end
    end
  end
end
