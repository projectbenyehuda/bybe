# frozen_string_literal: true

require 'rails_helper'

describe UpdateManifestationResponsibilityStatementsJob do
  let(:author) { create(:authority, name: 'Test Author') }
  let(:translator) { create(:authority, name: 'Test Translator') }
  let!(:manifestation1) { create(:manifestation, orig_lang: 'de', author: author, translator: translator) }
  let!(:manifestation2) { create(:manifestation, orig_lang: 'en', author: author) }

  it 'updates responsibility_statement for all provided manifestation ids' do
    # Change author name to trigger need for update
    manifestation1.update_column(:responsibility_statement, 'Old Statement 1')
    manifestation2.update_column(:responsibility_statement, 'Old Statement 2')

    described_class.perform_now([manifestation1.id, manifestation2.id])

    manifestation1.reload
    manifestation2.reload

    expect(manifestation1.responsibility_statement).to eq(manifestation1.author_string!)
    expect(manifestation2.responsibility_statement).to eq(manifestation2.author_string!)
  end

  context 'when error occurs' do
    before do
      allow(Rails.logger).to receive(:error)
      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(Manifestation).to receive(:recalc_responsibility_statement!)
        .and_raise(StandardError.new('Test error'))
      # rubocop:enable RSpec/AnyInstance
    end

    it 'handles errors gracefully for individual manifestations' do
      expect { described_class.perform_now([manifestation1.id]) }.not_to raise_error
      expect(Rails.logger).to have_received(:error)
        .once
        .with("Failed to recalculate responsibility_statement for Manifestation #{manifestation1.id}: Test error")
    end
  end

  it 'does nothing when manifestation_ids is empty' do
    expect { described_class.perform_now([]) }.not_to raise_error
  end

  it 'does nothing when manifestation_ids is nil' do
    expect { described_class.perform_now(nil) }.not_to raise_error
  end
end
