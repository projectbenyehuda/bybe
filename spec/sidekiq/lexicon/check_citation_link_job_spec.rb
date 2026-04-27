# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

Sidekiq::Testing.fake!

RSpec.describe Lexicon::CheckCitationLinkJob, type: :job do
  let(:person) { create(:lex_entry, :person).lex_item }
  let(:citation) { create(:lex_citation, person: person, link: 'https://example.com/article') }

  it 'enqueues a job when perform_async is called' do
    expect { described_class.perform_async(citation.id) }
      .to change(described_class.jobs, :size).by(1)
  end

  it 'updates link_http_status with the result from CheckExternalLinks' do
    checker = instance_double(Lexicon::CheckExternalLinks, check_url: 200)
    allow(Lexicon::CheckExternalLinks).to receive(:new).and_return(checker)

    described_class.new.perform(citation.id)

    expect(citation.reload.link_http_status).to eq(200)
  end

  it 'clears a previously-broken status when the new link is accessible' do
    citation.update_column(:link_http_status, 404)
    checker = instance_double(Lexicon::CheckExternalLinks, check_url: 200)
    allow(Lexicon::CheckExternalLinks).to receive(:new).and_return(checker)

    described_class.new.perform(citation.id)

    expect(citation.reload.link_broken?).to be false
  end

  it 'resets link_http_status to nil when link is blank' do
    citation.update_columns(link: nil, link_http_status: 404)

    described_class.new.perform(citation.id)

    expect(citation.reload.link_http_status).to be_nil
  end

  it 'logs a warning when citation is not found and does not raise' do
    allow(Rails.logger).to receive(:warn)
    expect { described_class.new.perform(999_999) }.not_to raise_error
    expect(Rails.logger).to have_received(:warn).with(/citation not found/i)
  end
end
