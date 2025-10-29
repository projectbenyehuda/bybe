# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserPreferencesController, type: :controller do
  let(:user) { create(:user) }
  let!(:base_user) { create(:base_user, user: user) }

  before do
    session[:user_id] = user.id if user.present?
  end

  describe 'GET #edit' do
    context 'when user is signed in' do
      it 'returns success' do
        get :edit
        expect(response).to be_successful
      end

      it 'assigns @base_user' do
        get :edit
        expect(assigns(:base_user)).to eq(base_user)
      end

      it 'assigns @email_frequency' do
        base_user.set_preference(:email_frequency, 'daily')
        get :edit
        expect(assigns(:email_frequency)).to eq('daily')
      end
    end

    context 'when user is not signed in' do
      let(:user) { nil }

      it 'redirects to root' do
        get :edit
        expect(response).to redirect_to('/')
      end
    end
  end

  describe 'PATCH #update' do
    context 'when user is signed in' do
      context 'with valid email_frequency' do
        it 'updates the preference' do
          patch :update, params: { email_frequency: 'weekly' }
          expect(base_user.reload.get_preference(:email_frequency)).to eq('weekly')
        end

        it 'redirects to edit with success message' do
          patch :update, params: { email_frequency: 'weekly' }
          expect(response).to redirect_to(edit_user_preferences_path)
          expect(flash[:notice]).to be_present
        end
      end

      context 'with invalid email_frequency' do
        it 'does not update the preference' do
          original_value = base_user.get_preference(:email_frequency)
          patch :update, params: { email_frequency: 'invalid' }
          expect(base_user.reload.get_preference(:email_frequency)).to eq(original_value)
        end

        it 'renders edit with error message' do
          patch :update, params: { email_frequency: 'invalid' }
          expect(response).to render_template(:edit)
          expect(flash[:error]).to be_present
        end
      end
    end

    context 'when user is not signed in' do
      let(:user) { nil }

      it 'redirects to root' do
        patch :update, params: { email_frequency: 'weekly' }
        expect(response).to redirect_to('/')
      end
    end
  end
end
