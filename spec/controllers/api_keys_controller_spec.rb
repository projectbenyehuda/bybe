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
      let!(:enabled_key) { create(:api_key, status: :enabled) }
      let!(:disabled_key) { create(:api_key, status: :disabled) }
      let!(:used_key) { create(:api_key, calls_count: 12_345, last_used_at: Time.zone.local(2026, 11, 9, 13, 45)) }

      it 'completes cuccessfully' do
        expect(subject).to be_successful
      end

      it 'lists keys with email, description, status and a toggle button' do
        get :index
        expect(response.body).to include(enabled_key.email, disabled_key.email, enabled_key.description)
        expect(response.body).to include(toggle_status_api_key_path(enabled_key))
        expect(response.body).to include(I18n.t('api_keys.index.disable'), I18n.t('api_keys.index.enable'))
        expect(response.body).to include(api_keys_path(format: :csv))
      end

      it 'shows usage stats for each key' do
        get :index
        page = Nokogiri::HTML(response.body)
        expect(page.at_css("#api_key_#{used_key.id} .calls-count").text).to eq '12,345'
        expect(page.at_css("#api_key_#{used_key.id} .last-used-at").text)
          .to eq I18n.l(used_key.last_used_at, format: :short)
        expect(page.at_css("#api_key_#{enabled_key.id} .calls-count").text).to eq '0'
        expect(page.at_css("#api_key_#{enabled_key.id} .last-used-at").text).to eq I18n.t('api_keys.index.never_used')
      end

      context 'when requesting CSV' do
        before { create_list(:api_key, 55) } # more than one HTML page

        it 'returns all keys, unpaginated' do
          get :index, format: :csv
          expect(response).to be_successful
          expect(response.media_type).to eq 'text/csv'
          rows = CSV.parse(response.body.delete_prefix("\uFEFF"), headers: true)
          expect(rows.size).to eq ApiKey.count
          expect(rows.headers).to eq %w(id email description key status created_at calls_count last_used_at)
          row = rows.find { |r| r['email'] == disabled_key.email }
          expect(row['status']).to eq 'disabled'
          expect(row['description']).to eq disabled_key.description
          expect(row['calls_count']).to eq '0'
          expect(row['last_used_at']).to be_nil
          used_row = rows.find { |r| r['email'] == used_key.email }
          expect(used_row['calls_count']).to eq '12345'
          expect(used_row['last_used_at']).to eq used_key.last_used_at.iso8601
        end
      end

      context 'when requesting CSV as a non-admin' do
        before { session[:user_id] = create(:user).id }

        it 'redirects away' do
          expect(get(:index, format: :csv)).to redirect_to '/'
        end
      end
    end
  end

  describe 'toggle_status' do
    subject(:toggle) { patch :toggle_status, params: { id: api_key.id } }

    let!(:api_key) { create(:api_key, status: :enabled) }

    include_context 'Unauthorized access to admin page'

    context 'when admin user is logged in' do
      include_context 'Admin user logged in'

      it 'disables an enabled key' do
        expect(toggle).to redirect_to api_keys_path
        expect(api_key.reload).to be_status_disabled
      end

      it 're-enables a disabled key' do
        api_key.update!(status: :disabled)
        toggle
        expect(api_key.reload).to be_status_enabled
      end

      it 'preserves the page parameter' do
        expect(patch(:toggle_status, params: { id: api_key.id, page: 2 })).to redirect_to api_keys_path(page: 2)
      end
    end

    context 'when a non-admin user tries it' do
      before { session[:user_id] = create(:user).id }

      it 'does not change the key' do
        toggle
        expect(api_key.reload).to be_status_enabled
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
