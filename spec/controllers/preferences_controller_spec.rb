# frozen_string_literal: true

require 'rails_helper'

describe PreferencesController do
  describe 'update' do
    subject { patch :update, params: { id: pref, value: value } }

    let!(:base_user) { create(:base_user, session_id: session.id.private_id) }
    let(:pref) { :fontsize }
    let(:value) { 10 }

    context 'when preference does not exists' do
      it 'creates new preference record' do
        expect { subject }.to change { base_user.preferences.count }.by(1)
        expect(subject).to be_successful
        base_user.reload
        expect(base_user.preferences.fontsize).to eq '10'
      end
    end

    context 'when preference already exists' do
      before do
        base_user.preferences.fontsize = 5
        base_user.preferences.save!
      end

      it 'updates preference record' do
        expect { subject }.not_to(change { base_user.preferences.count })
        expect(subject).to be_successful
        base_user.reload
        expect(base_user.preferences.fontsize).to eq '10'
      end
    end

    context 'when session cannot be created' do
      before do
        # Stub session.id to return nil even after trying to create it
        stub_session = double('session')
        allow(stub_session).to receive_messages(id: nil, '[]=': nil, delete: nil, '[]': nil)
        allow(controller).to receive(:session).and_return(stub_session)
      end

      it 'returns an error response' do
        expect(subject).to have_http_status(:unprocessable_content)
        json_response = response.parsed_body
        expect(json_response['status']).to eq('error')
        expect(json_response['message']).to eq('Could not create session')
      end

      it 'does not create a BaseUser record' do
        expect { subject }.not_to(change(BaseUser, :count))
      end
    end
  end
end
