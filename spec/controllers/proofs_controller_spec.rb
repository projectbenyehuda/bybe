# frozen_string_literal: true

require 'rails_helper'

describe ProofsController do
  include_context 'when editor logged in', :handle_proofs

  describe '#index' do
    let(:manifestation) { create(:manifestation, title: 'Search Term') }

    subject(:call) { get :index, params: filter }

    let!(:new_proof) { create(:proof, status: :new, item: manifestation) }
    let!(:escalated_proof) { create(:proof, status: :escalated) }
    let!(:fixed_proof) { create(:proof, status: :fixed, item: manifestation) }
    let!(:wontfix_proof) { create(:proof, status: :wontfix) }
    let!(:spam_proof) { create(:proof, status: :spam, item: manifestation) }

    context 'when no params are given' do
      let(:filter) { {} }

      it 'shows all proofs except spam' do
        expect(call).to be_successful
        expect(assigns[:proofs]).to contain_exactly(new_proof, escalated_proof, fixed_proof, wontfix_proof)
      end
    end

    context 'when filter by status is set' do
      let(:filter) { { status: :new } }

      it 'shows all proofs of selected status' do
        expect(call).to be_successful
        expect(assigns[:proofs]).to contain_exactly(new_proof)
      end
    end

    context 'when search term is given' do
      let(:filter) { { search: 'SEARCH TERM' } }

      it 'shows all matching proofs except spam' do
        expect(call).to be_successful
        expect(assigns[:proofs]).to contain_exactly(new_proof, fixed_proof)
      end
    end
  end

  describe '#purge' do
    subject(:call) { post :purge }

    before do
      create_list(:proof, 2, status: :new)
      create_list(:proof, 3, status: :spam)
      create_list(:proof, 2, status: :escalated)
      create_list(:proof, 2, status: :wontfix)
      create_list(:proof, 2, status: :fixed)
    end

    it 'removes all spam records' do
      expect { call }.to change(Proof, :count).by(-3)
      expect(call).to redirect_to proofs_path
      expect(Proof.where(status: :spam).count).to eq 0
    end
  end

  describe '#show' do
    subject { get :show, params: { id: proof.id } }

    context 'when proof is for manifestation' do
      let!(:manifestation) { create(:manifestation) }
      let!(:proof) { create(:proof, item: manifestation) }

      it { is_expected.to be_successful }
    end

    context 'when proof is for authority' do
      let!(:authority) { create(:authority) }
      let!(:proof) { create(:proof, item: authority) }

      it { is_expected.to be_successful }
    end
  end

  describe '#create' do
    subject(:call) { post :create, params: params, format: :js }

    let(:email) { 'john.doe@test.com' }
    let(:ziburit) { 'ביאליק' }
    let(:errors) { assigns(:errors) }

    let(:manifestation) { create(:manifestation) }

    let(:params) do
      {
        from: email,
        highlight: 'highlight text',
        what: 'what text',
        item_type: 'Manifestation',
        item_id: manifestation.id,
        ziburit: ziburit
      }
    end

    context 'when everything is OK' do
      it { is_expected.to be_successful }

      it 'creates new Proof record with given params' do
        expect { call }.to change(Proof, :count).by(1)
        expect(Proof.order(id: :desc).first).to have_attributes(
          status: 'new',
          from: email,
          what: 'what text',
          highlight: 'highlight text',
          item: manifestation
        )
      end
    end

    context 'when email is missing' do
      let(:email) { ' ' }

      it 'returns error' do
        expect(call).to be_unprocessable
        expect(response.parsed_body).to eq([I18n.t('proofs.create.email_missing')])
      end

      it { expect { call }.not_to(change(Proof, :count)) }
    end

    context 'when control question failed' do
      let(:ziburit) { 'WRONG' }

      it 'returns error' do
        expect(call).to be_unprocessable
        expect(response.parsed_body).to eq([I18n.t('proofs.create.ziburit_failed')])
      end

      it 'returns valid JSON error array' do
        call
        expect(response.content_type).to include('application/json')
        errors = response.parsed_body
        expect(errors).to be_an(Array)
        expect(errors.first).to be_a(String)
      end

      it { expect { call }.not_to(change(Proof, :count)) }
    end

    context 'when creating proof for authority' do
      let(:authority) { create(:authority) }

      let(:params) do
        {
          from: email,
          highlight: 'highlight text from toc',
          what: 'error in toc',
          item_type: 'Authority',
          item_id: authority.id,
          ziburit: ziburit
        }
      end

      it { is_expected.to be_successful }

      it 'creates new Proof record with Authority as item' do
        expect { call }.to change(Proof, :count).by(1)
        expect(Proof.order(id: :desc).first).to have_attributes(
          status: 'new',
          from: email,
          what: 'error in toc',
          highlight: 'highlight text from toc',
          item: authority
        )
      end
    end
  end

  describe '#resolve' do
    subject(:call) { post :resolve, params: { id: proof.id, fixed: fixed }.merge(additional_params) }

    let!(:manifestation) { create(:manifestation) }
    let!(:proof) { create(:proof, status: :new, item: manifestation, from: 'test@test.com') }

    before do
      allow(Notifications).to receive(:proof_wontfix)
    end

    context 'when fixed' do
      before do
        allow(Notifications).to receive(:proof_fixed).and_call_original
      end

      let(:additional_params) { { email: email, fixed_explanation: 'FIXED' } }
      let(:email) { 'no' }
      let(:fixed) { 'yes' }

      it 'marks proof as fixed and redirects to admin index page' do
        expect(call).to redirect_to admin_index_path
        expect(Notifications).not_to have_received(:proof_fixed)
        proof.reload
        expect(proof.status).to eq 'fixed'
      end

      context 'when current user is an admin' do
        before do
          current_user.update!(admin: true)
        end

        it 'marks proof as fixed and redirects to new proofs page' do
          expect(call).to redirect_to proofs_path(status: :new)
          expect(Notifications).not_to have_received(:proof_fixed)
          proof.reload
          expect(proof.status).to eq 'fixed'
        end
      end

      context 'when email is requested' do
        let(:email) { 'yes' }

        it 'marks proof as fixed and sends email' do
          expect(call).to redirect_to admin_index_path
          expect(Notifications).to have_received(:proof_fixed)
          proof.reload
          expect(proof.status).to eq 'fixed'
        end
      end
    end

    context 'when not fixed' do
      let(:fixed) { 'no' }

      before do
        allow(Notifications).to receive(:proof_wontfix).and_call_original
      end

      context 'when escalated' do
        let(:additional_params) { { escalate: 'yes' } }

        it 'marks proof as escalated and redirects to admin index page' do
          expect(call).to redirect_to admin_index_path
          expect(Notifications).not_to have_received(:proof_wontfix)
          proof.reload
          expect(proof.status).to eq 'escalated'
        end
      end

      context 'when wontfix' do
        let(:additional_params) { { escalate: 'no', wontfix_explanation: 'EXPLANATION' } }

        it 'marks proof as wontfix, sends an email and redirects to admin index page' do
          expect(call).to redirect_to admin_index_path
          expect(Notifications).to have_received(:proof_wontfix)
          proof.reload
          expect(proof.status).to eq 'wontfix'
        end

        context 'when email is not requested' do
          let(:additional_params) { { escalate: 'no', email: 'no', wontfix_explanation: 'EXPLANATION' } }

          it 'marks proof as wontfix without sending email' do
            expect(call).to redirect_to admin_index_path
            expect(Notifications).not_to have_received(:proof_wontfix)
            proof.reload
            expect(proof.status).to eq 'wontfix'
          end
        end
      end
    end

    context 'when resolving authority proof' do
      let!(:authority) { create(:authority) }
      let!(:proof) { create(:proof, status: :new, item: authority, from: 'test@test.com') }

      context 'when fixed with email' do
        let(:additional_params) { { email: 'yes', fixed_explanation: 'FIXED' } }
        let(:fixed) { 'yes' }

        before do
          allow(Notifications).to receive(:proof_fixed).and_call_original
        end

        it 'marks proof as fixed and sends notification with authority path' do
          expect(call).to redirect_to admin_index_path
          expect(Notifications).to have_received(:proof_fixed).with(
            proof,
            authority_path(authority),
            authority,
            'FIXED'
          )
          proof.reload
          expect(proof.status).to eq 'fixed'
        end
      end

      context 'when wontfix with email' do
        let(:additional_params) { { escalate: 'no', email: 'yes', wontfix_explanation: 'EXPLANATION' } }
        let(:fixed) { 'no' }

        before do
          allow(Notifications).to receive(:proof_wontfix).and_call_original
        end

        it 'marks proof as wontfix and sends notification with authority path' do
          expect(call).to redirect_to admin_index_path
          expect(Notifications).to have_received(:proof_wontfix).with(
            proof,
            authority_path(authority),
            authority,
            'EXPLANATION'
          )
          proof.reload
          expect(proof.status).to eq 'wontfix'
        end
      end
    end
  end
end
