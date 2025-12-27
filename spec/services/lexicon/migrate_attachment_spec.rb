# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::MigrateAttachment do
  subject(:call) { described_class.call(src, lex_entry) }

  let(:lex_entry) { create(:lex_entry, status: :raw) }

  context 'when proper local path is provided', vcr: { cassette_name: 'lexicon/mirate_attachment/03127-image002' } do
    let(:src) { '03127-files/image002.jpg' }

    context 'when LexFile with name listed in src exists' do
      let!(:lex_file) { create(:lex_file, fname: '03127.php') }

      it 'attaches resource to the lex entry associated with the LexFile and returns path to it' do
        entry = lex_file.lex_entry
        expect { call }.to change { entry.attachments.count }.by(1)
                             .and change { entry.legacy_links.count }.by(1)
        link = entry.legacy_links.last
        expect(link.old_path).to eq('03127-files/image002.jpg')
        expect(link.new_path).to be_present
        expect(call).to eq(link.new_path)
      end
    end

    context 'when LexFile with name listed in src does not exists' do
      it 'loads resource in provided entry attachment and returns path to it' do
        expect { call }.to change { lex_entry.attachments.count }.by(1).and change { lex_entry.legacy_links.count }.by(1)
        link = lex_entry.legacy_links.last
        expect(link.old_path).to eq('03127-files/image002.jpg')
        expect(link.new_path).to be_present
        expect(call).to eq link.new_path
      end
    end

    context 'when LegacyLink for the same path already exists' do
      let(:other_entry) { create(:lex_entry, :person) }
      let!(:legacy_link) do
        create(
          :lex_legacy_link,
          old_path: '03127-files/image002.jpg',
          new_path: 'https://test.com',
          lex_entry: other_entry
        )
      end

      it 'returns new_path from existing LegacyLink' do
        expect { call }.to not_change(ActiveStorage::Blob, :count)
                             .and(not_change(LexLegacyLink, :count))
        expect(call).to eq 'https://test.com'
      end
    end
  end

  context 'when global url pointing to lexicon is provided',
          vcr: { cassette_name: 'lexicon/mirate_attachment/03127-image002' } do
    let(:src) { 'https://benyehuda.org/lexicon/03127-files/image002.jpg' }

    it 'loads resource in entry attachment and returns path to it' do
      expect { call }.to change { lex_entry.attachments.count }.by(1).and change { lex_entry.legacy_links.count }.by(1)

      link = lex_entry.legacy_links.last
      expect(link.old_path).to eq('03127-files/image002.jpg')
      expect(link.new_path).to be_present
      expect(call).to eq link.new_path
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
