# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

describe InvolvedAuthority do
  describe 'validations' do
    subject { record.valid? }

    let(:role) { :author }
    let(:record) { build(:involved_authority, role: role, item: item) }

    context 'when item is not specified' do
      let(:item) { nil }

      it { is_expected.to be false }
    end

    context 'when expression is specified' do
      let(:item) { create(:expression) }

      context 'when work-level role is specified' do
        it { is_expected.to be false }
      end

      context 'when expression-level role is specified' do
        let(:role) { :editor }

        it { is_expected.to be_truthy }
      end
    end

    context 'when work is specified' do
      let(:item) { create(:work) }

      context 'when work-level role is specified' do
        it { is_expected.to be_truthy }
      end

      context 'when expression-level role is specified' do
        let(:role) { :translator }

        it { is_expected.to be false }
      end
    end
  end

  describe 'responsibility_statement update callbacks' do
    let!(:manifestation) { create(:manifestation, orig_lang: 'de') }
    let(:work) { manifestation.expression.work }
    let(:expression) { manifestation.expression }
    let(:new_author) { create(:authority, name: 'New Author') }
    let(:new_translator) { create(:authority, name: 'New Translator') }

    around do |example|
      Sidekiq::Testing.inline! do
        example.run
      end
    end

    describe 'when creating a new involved authority on work' do
      it 'enqueues job to update the manifestation responsibility_statement' do
        expect do
          work.involved_authorities.create!(role: :author, authority: new_author)
        end.to change(UpdateManifestationResponsibilityStatementsJob.jobs, :size).by(1)
      end

      it 'updates the manifestation responsibility_statement when job runs' do
        expect do
          work.involved_authorities.create!(role: :author, authority: new_author)
          manifestation.reload
        end.to change { manifestation.responsibility_statement }
      end
    end

    describe 'when creating a new involved authority on expression' do
      it 'enqueues job to update the manifestation responsibility_statement' do
        expect do
          expression.involved_authorities.create!(role: :translator, authority: new_translator)
        end.to change(UpdateManifestationResponsibilityStatementsJob.jobs, :size).by(1)
      end

      it 'updates the manifestation responsibility_statement when job runs' do
        expect do
          expression.involved_authorities.create!(role: :translator, authority: new_translator)
          manifestation.reload
        end.to change { manifestation.responsibility_statement }
      end
    end

    describe 'when destroying an involved authority' do
      let!(:involved_auth) { work.involved_authorities.first }

      it 'enqueues job to update the manifestation responsibility_statement' do
        expect do
          involved_auth.destroy!
        end.to change(UpdateManifestationResponsibilityStatementsJob.jobs, :size).by(1)
      end

      it 'updates the manifestation responsibility_statement when job runs' do
        expect do
          involved_auth.destroy!
          manifestation.reload
        end.to change { manifestation.responsibility_statement }
      end
    end
  end
end
