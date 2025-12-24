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
end
