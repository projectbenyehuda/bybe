require 'rails_helper'

describe SessionController do
  describe 'create' do
    before(:all) do
      OmniAuth.config.test_mode = true
      OmniAuth.config.add_mock(
        :google_oauth2,
        { uid: 'UID', info: { email: 'test@test.com', name: 'Asaf' }, credentials: { token: 'TOKEN' } }
      )
    end

    before do
      request.env['omniauth.auth'] = OmniAuth.config.mock_auth[:google_oauth2]
    end

    after(:all) do
      OmniAuth.config.test_mode = false
      OmniAuth.config.mock_auth[:google_oauth2] = nil
    end

    subject { post :create }

    context 'when new User signs up' do
      context 'when anonymous BaseUser record exists' do
        let!(:base_user) { BaseUser.create(session_id: session.id.private_id) }

        it 'creates new User record and updates BaseUser record' do
          expect { subject }.to change { User.count }.by(1).and change { BaseUser.count }.by(0)
          u = User.order(id: :desc).first
          expect(u).to have_attributes(
            email: 'test@test.com',
            name: 'Asaf',
            provider: 'google_oauth2',
            uid: 'UID',
            oauth_token: 'TOKEN'
          )

          base_user.reload
          expect(base_user).to have_attributes(user: u, session_id: nil)
          expect(session['user_id']).to eq u.id
        end
      end

      context 'when no anonymous BaseUser record exists' do
        it 'creates new User record and new BaseUser record' do
          expect { subject }.to change { User.count }.by(1).and change { BaseUser.count }.by(1)
          u = User.order(id: :desc).first
          expect(u).to have_attributes(
            email: 'test@test.com',
            name: 'Asaf',
            provider: 'google_oauth2',
            uid: 'UID',
            oauth_token: 'TOKEN'
          )

          base_user = BaseUser.order(id: :desc).first
          expect(base_user).to have_attributes(user: u, session_id: nil)
          expect(session['user_id']).to eq u.id
        end
      end
    end

    context 'when existing User sign in' do
      let!(:user) { create(:user, provider: 'google_oauth2', uid: 'UID') }
      let!(:existing_base_user) { create(:base_user, user: user) }
      context 'when anonymous BaseUser record exists' do
        let!(:base_user) { BaseUser.create(session_id: session.id.private_id) }

        it 'uses existing User record and deletes anonymous BaseUser' do
          expect { subject }.to change { User.count }.by(0).and change { BaseUser.count }.by(-1)
          user.reload
          expect(user).to have_attributes(
            email: 'test@test.com',
            name: 'Asaf',
            provider: 'google_oauth2',
            uid: 'UID',
            oauth_token: 'TOKEN'
          )

          # If user exists we drop BaseUser from anonymous session because existing user should already have one
          expect { base_user.reload }.to raise_error(ActiveRecord::RecordNotFound)

          # ensuring existing BaseUser was kept
          expect(existing_base_user.user_id).to eq user.id
        end
      end

      context 'when no anonymous BaseUser record exists' do
        it 'uses existing User record' do
          expect { subject }.to change { User.count }.by(0).and change { BaseUser.count }.by(0)
          user.reload
          expect(user).to have_attributes(
            email: 'test@test.com',
            name: 'Asaf',
            provider: 'google_oauth2',
            uid: 'UID',
            oauth_token: 'TOKEN'
          )
          # ensuring existing BaseUser was kept
          expect(existing_base_user.user_id).to eq user.id
        end
      end
    end
  end
end
