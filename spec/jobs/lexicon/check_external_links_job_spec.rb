# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::CheckExternalLinksJob do
  let(:person) { create(:lex_person) }
  let(:entry) { create(:lex_entry, :person, lex_item: person) }

  it 'calls CheckExternalLinks for the given entry' do
    allow(Lexicon::CheckExternalLinks).to receive(:call)
    described_class.new.perform(entry.id)
    expect(Lexicon::CheckExternalLinks).to have_received(:call).with(instance_of(LexEntry))
  end

  it 'logs a warning when entry is not found and does not raise' do
    allow(Rails.logger).to receive(:warn)
    expect { described_class.new.perform(999_999) }.not_to raise_error
    expect(Rails.logger).to have_received(:warn).with(/entry not found/i)
  end
end
