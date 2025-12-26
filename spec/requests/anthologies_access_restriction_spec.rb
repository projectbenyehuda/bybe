# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Anthologies access restriction', type: :request do
  let(:regular_user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }

  def login_as(user)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  describe 'PUT /anthologies/:id' do
    context 'when a non-admin user tries to set access to pub' do
      let(:anthology) { create(:anthology, user: regular_user, access: :priv) }

      before do
        login_as(regular_user)
      end

      it 'rejects the update and returns an error', :aggregate_failures do
        put anthology_path(anthology), params: { anthology: { access: 'pub' } }, xhr: true

        expect(response).to have_http_status(:ok) # respond_with_error returns 200
        anthology.reload
        expect(anthology.access).not_to eq('pub')
        expect(anthology.access).to eq('priv') # Should remain unchanged
      end

      it 'allows updating to priv', :aggregate_failures do
        anthology.update!(access: :unlisted)
        put anthology_path(anthology), params: { anthology: { access: 'priv' } }, as: :json

        expect(response).to have_http_status(:ok)
        anthology.reload
        expect(anthology.access).to eq('priv')
      end

      it 'allows updating to unlisted', :aggregate_failures do
        put anthology_path(anthology), params: { anthology: { access: 'unlisted' } }, as: :json

        expect(response).to have_http_status(:ok)
        anthology.reload
        expect(anthology.access).to eq('unlisted')
      end
    end

    context 'when an admin user tries to set access to pub' do
      let(:admin_anthology) { create(:anthology, user: admin_user, access: :priv) }
      let(:other_user_anthology) { create(:anthology, user: regular_user, access: :priv) }

      before do
        login_as(admin_user)
      end

      it 'allows the update on own anthology', :aggregate_failures do
        put anthology_path(admin_anthology), params: { anthology: { access: 'pub' } }, as: :json

        expect(response).to have_http_status(:ok)
        admin_anthology.reload
        expect(admin_anthology.access).to eq('pub')
      end

      it 'allows admin to set access to pub on any anthology', :aggregate_failures do
        put anthology_path(other_user_anthology), params: { anthology: { access: 'pub' } }, as: :json

        expect(response).to have_http_status(:ok)
        other_user_anthology.reload
        expect(other_user_anthology.access).to eq('pub')
      end
    end

    context 'when updating other fields' do
      let(:anthology) { create(:anthology, user: regular_user, access: :priv) }

      before do
        login_as(regular_user)
      end

      it 'allows non-admin users to update title without changing access', :aggregate_failures do
        put anthology_path(anthology), params: { anthology: { title: 'New Title' } }, as: :json

        expect(response).to have_http_status(:ok)
        anthology.reload
        expect(anthology.title).to eq('New Title')
        expect(anthology.access).to eq('priv')
      end
    end
  end
end
