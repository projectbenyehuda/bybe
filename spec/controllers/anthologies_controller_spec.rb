require 'rails_helper'

describe AnthologiesController do
  describe '#show' do
    let(:user) { nil }

    let(:access) { :priv }
    let(:anthology) { create(:anthology, access: access) }

    subject { get :show, params: { id: anthology.id } }

    before do
      if user.present?
        session[:user_id] = user.id
      end
    end

    context 'when user is not signed in' do
      it { is_expected.to redirect_to '/' }
    end

    context 'when user signed in' do
      let(:user) { create(:user) }

      context "when user tries to see other user's anthology" do
        context 'when anthology is public' do
          let(:access) { :pub }
          it { is_expected.to be_successful }

          it 'assigns @taggings' do
            subject
            expect(assigns(:taggings)).to eq(anthology.taggings)
          end
        end

        context 'when anthology is unlisted' do
          let(:access) { :unlisted }
          it { is_expected.to be_successful }
        end

        context 'when anthology is private' do
          it { is_expected.to redirect_to '/' }
        end
      end
    end
  end

  describe '#clone' do
    let(:user) { create(:user) }

    before do
      session[:user_id] = user.id
    end

    let!(:anthology) { create(:anthology, user: user, access: :pub) }

    subject(:request) { get :clone, params: { id: anthology.id }, format: format, xhr: true }

    context 'when html format' do
      let(:format) { :html }

      it 'creates new anthology and redirects to it' do
        expect { request }.to change { Anthology.count }.by(1)

        new_anthology = Anthology.order(id: :desc).first
        expect(response).to redirect_to new_anthology
      end
    end

    context 'when js format' do
      let(:format) { :js }

      it 'creates new anthology and renders js script' do
        expect { request }.to change { Anthology.count }.by(1)
        expect(response).to be_successful
      end
    end
  end

  describe '#browse' do
    let(:user) { nil }
    let!(:public_anthology) { create(:anthology, access: :pub, title: 'Public Anthology') }
    let!(:private_anthology) { create(:anthology, access: :priv, title: 'Private Anthology') }
    let!(:unlisted_anthology) { create(:anthology, access: :unlisted, title: 'Unlisted Anthology') }

    subject { get :browse, params: params }

    before do
      session[:user_id] = user.id if user.present?
    end

    context 'when user is not signed in' do
      let(:params) { {} }

      it 'shows only public anthologies' do
        subject
        expect(assigns(:anthologies).to_a).to eq([public_anthology])
      end
    end

    context 'when user is a regular user' do
      let(:user) { create(:user, admin: false) }
      let(:params) { {} }

      it 'shows only public anthologies' do
        subject
        expect(assigns(:anthologies).to_a).to eq([public_anthology])
      end

      it 'ignores show_all parameter' do
        get :browse, params: { show_all: '1' }
        expect(assigns(:anthologies).to_a).to eq([public_anthology])
      end
    end

    context 'when user is an admin' do
      let(:user) { create(:user, admin: true) }

      context 'without show_all parameter' do
        let(:params) { {} }

        it 'shows only public anthologies by default' do
          subject
          expect(assigns(:anthologies).to_a).to eq([public_anthology])
        end

        it 'loads user list for owner reassignment' do
          subject
          expect(assigns(:all_users)).to be_present
          expect(assigns(:all_users)).to be_a(Array)
        end
      end

      context 'with show_all parameter' do
        let(:params) { { show_all: '1' } }

        it 'shows all anthologies including private and unlisted' do
          subject
          anthology_ids = assigns(:anthologies).pluck(:id).sort
          expected_ids = [public_anthology.id, private_anthology.id, unlisted_anthology.id].sort
          expect(anthology_ids).to eq(expected_ids)
        end

        it 'sets @show_all to true' do
          subject
          expect(assigns(:show_all)).to be true
        end
      end
    end
  end

  describe 'admin authorization' do
    let(:anthology_owner) { create(:user) }
    let(:admin_user) { create(:user, admin: true) }
    let(:regular_user) { create(:user, admin: false) }
    let(:anthology) { create(:anthology, user: anthology_owner, title: 'Test Anthology', access: :pub) }

    describe '#edit' do
      subject { get :edit, params: { id: anthology.id } }

      before { session[:user_id] = user.id if user }

      context 'when user is the owner' do
        let(:user) { anthology_owner }

        it 'allows access' do
          subject
          expect(response).to be_successful
        end
      end

      context 'when user is an admin' do
        let(:user) { admin_user }

        it 'allows access' do
          subject
          expect(response).to be_successful
        end
      end

      context 'when user is neither owner nor admin' do
        let(:user) { regular_user }

        it 'redirects to root with error' do
          subject
          expect(response).to redirect_to('/')
          expect(flash[:error]).to be_present
        end
      end

      context 'when user is not signed in' do
        let(:user) { nil }

        it 'redirects to root with error' do
          subject
          expect(response).to redirect_to('/')
        end
      end
    end

    describe '#update' do
      let(:new_title) { 'Updated Title' }
      let(:new_access) { 'unlisted' }

      subject do
        patch :update, params: { id: anthology.id, anthology: { title: new_title, access: new_access } }, format: :json
      end

      before { session[:user_id] = user.id if user }

      context 'when user is the owner' do
        let(:user) { anthology_owner }

        it 'allows update' do
          subject
          anthology.reload
          expect(anthology.title).to eq(new_title)
          expect(anthology.access).to eq(new_access)
        end
      end

      context 'when user is an admin' do
        let(:user) { admin_user }

        it 'allows admin to update any anthology' do
          subject
          anthology.reload
          expect(anthology.title).to eq(new_title)
          expect(anthology.access).to eq(new_access)
        end
      end

      context 'when user is neither owner nor admin' do
        let(:user) { regular_user }

        it 'prevents update and redirects' do
          subject
          anthology.reload
          expect(anthology.title).not_to eq(new_title)
          expect(response).to redirect_to('/')
        end
      end

      context 'when user is not signed in' do
        let(:user) { nil }

        it 'prevents update and redirects' do
          subject
          anthology.reload
          expect(anthology.title).not_to eq(new_title)
          expect(response).to redirect_to('/')
        end
      end

      context 'owner reassignment' do
        let(:user) { admin_user }
        let(:new_owner) { create(:user) }

        subject do
          patch :update, params: { id: anthology.id, anthology: { user_id: new_owner.id } }, format: :json
        end

        it 'allows admin to change anthology owner' do
          subject
          anthology.reload
          expect(anthology.user_id).to eq(new_owner.id)
        end

        it 'allows admin to reassign anthology from one user to another' do
          another_user = create(:user)
          patch :update, params: { id: anthology.id, anthology: { user_id: another_user.id } }, format: :json
          anthology.reload
          expect(anthology.user_id).to eq(another_user.id)
        end

        context 'when user is not an admin' do
          let(:user) { regular_user }

          it 'prevents owner change' do
            original_owner_id = anthology.user_id
            subject
            anthology.reload
            expect(anthology.user_id).to eq(original_owner_id)
            expect(response).to redirect_to('/')
          end
        end
      end
    end

    describe '#destroy' do
      subject { delete :destroy, params: { id: anthology.id }, format: :json }

      before do
        anthology # Ensure anthology is created before tests
        session[:user_id] = user.id if user
      end

      context 'when user is the owner' do
        let(:user) { anthology_owner }

        it 'allows deletion' do
          expect { subject }.to change { Anthology.count }.by(-1)
        end
      end

      context 'when user is an admin' do
        let(:user) { admin_user }

        it 'allows admin to delete any anthology' do
          expect { subject }.to change { Anthology.count }.by(-1)
        end
      end

      context 'when user is neither owner nor admin' do
        let(:user) { regular_user }

        it 'prevents deletion' do
          expect { subject }.not_to change { Anthology.count }
          expect(response).to redirect_to('/')
        end
      end

      context 'when user is not signed in' do
        let(:user) { nil }

        it 'prevents deletion' do
          expect { subject }.not_to change { Anthology.count }
          expect(response).to redirect_to('/')
        end
      end
    end
  end
end
