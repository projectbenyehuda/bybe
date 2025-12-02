# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::MigrateAttachment do
  subject(:call) { described_class.call(src, lex_entry) }

  let(:lex_entry) { create(:lex_entry, status: :raw) }

  context 'when proper local path is provided', vcr: { cassette_name: 'lexicon/mirate_attachment/03127-image002' } do
    let(:src) { '03127-files/image002.jpg' }

    it 'loads resource in entry attachment and returns path to it' do
      expect { call }.to change { lex_entry.attachments.count }.by(1).and change { lex_entry.legacy_links.count }.by(1)

      expect(lex_entry.legacy_links.last.old_path).to eq('03127-files/image002.jpg')
      expect(lex_entry.legacy_links.last.new_path).to be_present
      expect(call).not_to be_nil
    end
  end

  context 'when global url pointing to lexicon is provided',
          vcr: { cassette_name: 'lexicon/mirate_attachment/03127-image002' } do
    let(:src) { 'https://benyehuda.org/lexicon/03127-files/image002.jpg' }

    it 'loads resource in entry attachment and returns path to it' do
      expect { call }.to change { lex_entry.attachments.count }.by(1).and change { lex_entry.legacy_links.count }.by(1)

      expect(lex_entry.legacy_links.last.old_path).to eq('03127-files/image002.jpg')
      expect(lex_entry.legacy_links.last.new_path).to be_present
      expect(call).not_to be_nil
    end
  end

  context 'when global url pointing to resource outside of lexicon is provided' do
    let(:src) { 'https://www.gnu.org/graphics/heckert_gnu.png' }

    it 'does not creates new attachments and returns nil' do
      expect { call }.to not_change { lex_entry.attachments.count }.and(not_change { lex_entry.legacy_links.count })
      expect(call).to be_nil
    end
  end
end
