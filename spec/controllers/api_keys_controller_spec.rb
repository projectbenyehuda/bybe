require 'rails_helper'

describe ApiKeysController do
  render_views

  describe 'new' do
    it 'shows successfully' do
      get :new
      expect(response).to be_successful
    end
  end

  describe 'create' do
    let(:correct_ziburit) { 'חיים נחמן ביאליק‎' }
    subject { post :create, params: params }

    context 'when all required fields are filled in correctly' do
      let(:params) { { api_key: { description: 'test', email: 'New@test.com' }, ziburit: correct_ziburit } }
      it 'creates new API Key and redirects to root page' do
        expect { subject }.to change { ApiKey.count }.by(1).and change { ActionMailer::Base.deliveries.size }.by(2)
        expect(response).to redirect_to '/'
        expect(flash.notice).to eq 'Api key was successfully created, check email for details'

        key = ApiKey.order(id: :desc).first
        expect(key).to have_attributes(email: 'new@test.com', description: 'test', status: 'enabled')
        expect(key.key).to_not be_empty

        # One email is sent to person who requested API Key
        email = ActionMailer::Base.deliveries[-1]
        expect(email).to have_attributes(subject: I18n.t('api_keys_mailer.key_created.subject'), to: [key.email])
        expect(email.body).to include(key.key)

        # Second email is sent to editor
        email = ActionMailer::Base.deliveries[-2]
        expect(email).to have_attributes(subject: I18n.t('api_keys_mailer.key_created_to_editor.subject'), to: [ApiKeysMailer::EDITOR_EMAIL])
        expect(email.body).to include(key.description)
        expect(email.body).to_not include(key.key)
      end
    end

    context 'when some problem occurs' do
      context 'when email is already taken' do
        let!(:existing_key) { create(:api_key) }
        let(:params) { { api_key: { description: 'test', email: existing_key.email }, ziburit: correct_ziburit } }

        it 'fails with unprocessable_content status' do
          expect { subject }.to_not change { ApiKey.count }
          expect(response).to be_unprocessable
        end
      end

      context 'when incorrect antispam value provided' do
        let!(:existing_key) { create(:api_key) }
        let(:params) { { api_key: { description: 'test', email: existing_key.email }, ziburit: 'Pushkin' } }

        it 'fails with unprocessable_content status' do
          expect { subject }.to_not change { ApiKey.count }
          expect(response).to be_unprocessable
        end
      end

    end
  end

  describe 'index' do
    let(:subject) { get :index }

    include_context 'Unauthorized access to admin page'

    context 'when admin user is logged in' do
      include_context 'Admin user logged in'
      it 'completes cuccessfully' do
        expect(subject).to be_successful
      end
    end
  end

  describe 'edit' do
    let!(:api_key) { create(:api_key) }

    let(:subject) { get :edit, params: {id: api_key.id } }

    include_context 'Unauthorized access to admin page'

    context 'when admin user is logged in' do
      include_context 'Admin user logged in'
      it 'completes cuccessfully' do
        expect(subject).to be_successful
      end
    end
  end

  describe 'update' do
    let!(:api_key) { create(:api_key, description: 'Old Description', status: 'enabled') }

    let(:params) { { id: api_key.id, api_key: { description: 'New Description', status: 'disabled' } } }
    let(:subject) { post :update, params: params }

    include_context 'Unauthorized access to admin page'

    context 'when admin user is logged in' do
      include_context 'Admin user logged in'
      context 'when all params are correct' do
        it 'completes successfully' do
          expect(subject).to redirect_to api_keys_path
          api_key.reload
          expect(api_key).to have_attributes(description: 'New Description', status: 'disabled')
        end
      end

      context 'when validation fails' do
        let(:params) { { id: api_key.id, api_key: { description: 'New Description', status: '' } } }
        it 'fails with unprocessable_content status' do
          expect(subject).to be_unprocessable
          api_key.reload
          expect(api_key).to have_attributes(description: 'Old Description', status: 'enabled')
        end
      end
    end
  end

  describe 'destroy' do
    let!(:api_key) { create(:api_key) }

    let(:subject) { delete :destroy, params: { id: api_key.id } }

    include_context 'Unauthorized access to admin page'

    context 'when admin user is logged in' do
      include_context 'Admin user logged in'
      it 'deletes API key and redirects to root page' do
        expect { subject }.to change { ApiKey.count }.by(-1)
        expect(subject).to redirect_to api_keys_path
      end
    end
  end
end
