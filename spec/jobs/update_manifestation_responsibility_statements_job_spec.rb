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

  it 'handles errors gracefully for individual manifestations' do
    allow_any_instance_of(Manifestation).to receive(:recalc_responsibility_statement!).and_raise(StandardError.new('Test error'))
    expect(Rails.logger).to receive(:error).at_least(:once)

    expect { described_class.perform_now([manifestation1.id]) }.not_to raise_error
  end

  it 'does nothing when manifestation_ids is empty' do
    expect { described_class.perform_now([]) }.not_to raise_error
  end

  it 'does nothing when manifestation_ids is nil' do
    expect { described_class.perform_now(nil) }.not_to raise_error
  end
end
