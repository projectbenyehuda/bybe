# frozen_string_literal: true

require 'rails_helper'

describe InvolvedAuthority do
  include ActiveJob::TestHelper

  describe 'roles' do
    it 'includes the annotator role' do
      expect(described_class.roles).to include('annotator')
    end

    it 'allows the annotator role on both works and expressions' do
      expect(described_class::WORK_ROLES).to include('annotator')
      expect(described_class::EXPRESSION_ROLES).to include('annotator')
    end

    it 'presents annotator after author and before translator' do
      order = described_class::ROLES_PRESENTATION_ORDER
      expect(order.index('annotator')).to be > order.index('author')
      expect(order.index('annotator')).to be < order.index('translator')
    end

    it 'presents every role exactly once' do
      expect(described_class::ROLES_PRESENTATION_ORDER).to match_array(described_class.roles.keys)
    end

    %i(he en).each do |locale|
      it "has #{locale} translations for every role" do
        described_class.roles.each_key do |role|
          expect(I18n.t(role, scope: 'involved_authority.role', locale: locale, raise: true)).to be_present
          expect(I18n.t(role, scope: 'involved_authority.abstract_roles', locale: locale, raise: true)).to be_present
        end
      end
    end
  end

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

    describe 'job enqueueing' do
      before do
        ActiveJob::Base.queue_adapter = :test
        clear_enqueued_jobs
        clear_performed_jobs
      end

      it 'enqueues job when creating a new involved authority on work' do
        expect do
          work.involved_authorities.create!(role: :author, authority: new_author)
        end.to have_enqueued_job(UpdateManifestationResponsibilityStatementsJob)
      end

      it 'enqueues job when creating a new involved authority on expression' do
        expect do
          expression.involved_authorities.create!(role: :translator, authority: new_translator)
        end.to have_enqueued_job(UpdateManifestationResponsibilityStatementsJob)
      end

      it 'enqueues job when destroying an involved authority' do
        involved_auth = work.involved_authorities.first
        expect do
          involved_auth.destroy!
        end.to have_enqueued_job(UpdateManifestationResponsibilityStatementsJob)
      end
    end

    describe 'responsibility_statement updates' do
      before do
        ActiveJob::Base.queue_adapter = :test
        clear_enqueued_jobs
        clear_performed_jobs
      end

      it 'updates the manifestation responsibility_statement when creating work authority' do
        expect do
          perform_enqueued_jobs do
            work.involved_authorities.create!(role: :author, authority: new_author)
          end
          manifestation.reload
        end.to(change(manifestation, :responsibility_statement))
      end

      it 'updates the manifestation responsibility_statement when creating expression authority' do
        expect do
          perform_enqueued_jobs do
            expression.involved_authorities.create!(role: :translator, authority: new_translator)
          end
          manifestation.reload
        end.to(change(manifestation, :responsibility_statement))
      end

      it 'updates the manifestation responsibility_statement when destroying an involved authority' do
        involved_auth = work.involved_authorities.first
        expect do
          perform_enqueued_jobs do
            involved_auth.destroy!
          end
          manifestation.reload
        end.to(change(manifestation, :responsibility_statement))
      end
    end
  end
end
