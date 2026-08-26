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

      it 'redirects to login' do
        get :edit
        expect(response).to redirect_to(session_login_path)
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

      # by-cnh.4: leaving a throttled frequency used to strand whatever was already buffered, since
      # NotificationDigestJob only ever visits users whose current preference is daily or weekly.
      context 'when leaving a throttled frequency with notifications already buffered' do
        let!(:buffered) { create_list(:pending_notification, 2, recipient_email: user.email) }

        before do
          base_user.set_preference(:email_frequency, 'daily')
          ActionMailer::Base.deliveries.clear
        end

        it 'flushes the buffer when switching to unlimited' do
          expect { patch :update, params: { email_frequency: 'unlimited' } }
            .to change(PendingNotification, :count).by(-2)
          expect(ActionMailer::Base.deliveries.last.to).to eq([user.email])
        end

        it 'discards the buffer, silently, when switching to none' do
          expect { patch :update, params: { email_frequency: 'none' } }
            .to change(PendingNotification, :count).by(-2)
          expect(ActionMailer::Base.deliveries).to be_empty
        end

        it 'leaves the buffer alone when switching between throttled frequencies' do
          expect { patch :update, params: { email_frequency: 'weekly' } }
            .not_to change(PendingNotification, :count)
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

      it 'redirects to login' do
        patch :update, params: { email_frequency: 'weekly' }
        expect(response).to redirect_to(session_login_path)
      end
    end
  end
end
