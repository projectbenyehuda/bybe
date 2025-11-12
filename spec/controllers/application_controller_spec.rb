require 'rails_helper'

describe ApplicationController do
  describe '.base_user' do
    subject { @controller.base_user }

    let!(:user) { create(:user) }

    context 'when user is not authenticated' do
      context 'when BaseUser with given session_id exists' do
        let!(:base_user) { create(:base_user, session_id: session.id.private_id) }

        it 'returns it' do
          expect { subject }.not_to(change { BaseUser.count })
          expect(subject).to eq base_user
        end
      end

      context 'when no BaseUser record exists' do
        it { is_expected.to be_nil }

        context 'when force_create arg is provided' do
          subject { @controller.base_user(true) }

          it 'creates new one' do
            expect { subject }.to change { BaseUser.count }.by(1)
            bu = BaseUser.order(id: :desc).first
            expect(subject).to eq bu
            expect(bu.session_id).to eq session.id.private_id
            expect(bu.user).to be_nil
          end
        end
      end
    end

    context 'when user is authenticated' do
      before do
        session[:user_id] = user.id
      end

      context 'when BaseUser record with given user_id exists' do
        let!(:base_user) { create(:base_user, user: user) }

        it 'returns it' do
          expect { subject }.not_to(change { BaseUser.count })
          expect(subject).to eq base_user
        end
      end

      context 'when no BaseUser record exists' do
        it { is_expected.to be_nil }

        context 'when force_create arg is provided' do
          subject { @controller.base_user(true) }

          it 'creates new one' do
            expect { subject }.to change { BaseUser.count }.by(1)
            bu = BaseUser.order(id: :desc).first
            expect(subject).to eq bu
            expect(bu.user_id).to eq user.id
            expect(bu.session_id).to be_nil
          end
        end
      end
    end
  end
end
