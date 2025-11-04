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

  describe 'intellectual property recalculation' do
    let(:author_pd) { create(:authority, intellectual_property: :public_domain) }
    let(:translator_copyrighted) { create(:authority, intellectual_property: :copyrighted) }
    let(:work) { create(:work) }
    let(:expression) { create(:expression, work: work, intellectual_property: :public_domain) }
    let!(:manifestation) { create(:manifestation, expression: expression) }

    context 'when adding a copyrighted translator to a public domain work' do
      before do
        work.involved_authorities.create!(authority: author_pd, role: :author)
      end

      it 'recalculates expression intellectual property to copyrighted' do
        expect do
          expression.involved_authorities.create!(authority: translator_copyrighted, role: :translator)
        end.to change { expression.reload.intellectual_property }.from('public_domain').to('copyrighted')
      end
    end

    context 'when removing a copyrighted authority leaves only public domain' do
      let!(:author_ia) { work.involved_authorities.create!(authority: author_pd, role: :author) }
      let!(:translator_ia) { expression.involved_authorities.create!(authority: translator_copyrighted, role: :translator) }

      before do
        expression.update_column(:intellectual_property, Expression.intellectual_properties[:copyrighted])
      end

      it 'recalculates expression intellectual property to public domain' do
        expect do
          translator_ia.destroy!
        end.to change { expression.reload.intellectual_property }.from('copyrighted').to('public_domain')
      end
    end

    context 'when all authorities are public domain' do
      let!(:author_ia) { work.involved_authorities.create!(authority: author_pd, role: :author) }

      it 'keeps expression as public domain' do
        expect(expression.reload.intellectual_property).to eq('public_domain')
  end
  describe 'responsibility_statement update callbacks' do
    let!(:manifestation) { create(:manifestation, orig_lang: 'de') }
    let(:work) { manifestation.expression.work }
    let(:expression) { manifestation.expression }
    let(:new_author) { create(:authority, name: 'New Author') }
    let(:new_translator) { create(:authority, name: 'New Translator') }

    describe 'job enqueueing' do
      around do |example|
        Sidekiq::Testing.fake! do
          example.run
        end
      end

      it 'enqueues job when creating a new involved authority on work' do
        expect do
          work.involved_authorities.create!(role: :author, authority: new_author)
        end.to change(UpdateManifestationResponsibilityStatementsJob.jobs, :size).by(1)
      end

      it 'enqueues job when creating a new involved authority on expression' do
        expect do
          expression.involved_authorities.create!(role: :translator, authority: new_translator)
        end.to change(UpdateManifestationResponsibilityStatementsJob.jobs, :size).by(1)
      end

      it 'enqueues job when destroying an involved authority' do
        involved_auth = work.involved_authorities.first
        expect do
          involved_auth.destroy!
        end.to change(UpdateManifestationResponsibilityStatementsJob.jobs, :size).by(1)
      end
    end

    describe 'responsibility_statement updates' do
      around do |example|
        Sidekiq::Testing.inline! do
          example.run
        end
      end

      it 'updates the manifestation responsibility_statement when creating work authority' do
        expect do
          work.involved_authorities.create!(role: :author, authority: new_author)
          manifestation.reload
        end.to change { manifestation.responsibility_statement }
      end

      it 'updates the manifestation responsibility_statement when creating expression authority' do
        expect do
          expression.involved_authorities.create!(role: :translator, authority: new_translator)
          manifestation.reload
        end.to change { manifestation.responsibility_statement }
      end

      it 'updates the manifestation responsibility_statement when destroying an involved authority' do
        involved_auth = work.involved_authorities.first
        expect do
          involved_auth.destroy!
          manifestation.reload
        end.to change { manifestation.responsibility_statement }
      end
    end
  end      
end
