# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::FlagUnmigratedCitations do
  subject(:call) { described_class.call(lex_file, lex_person, content) }

  let(:lex_file) { create(:lex_file, :person, entry_status: :raw) }
  let(:lex_person) { create(:lex_person) }

  let(:populated_bibliography) do
    '<p><font><a name="Bib.">על המחבר ויצירתו:</a></font></p>' \
      '<blockquote><ul><li>כהן, דוד. ביקורת. הארץ, 2020, עמ׳ 5.</li></ul></blockquote>'
  end

  context 'when the bibliography section holds items but nothing was migrated' do
    let(:content) { populated_bibliography }

    it 'flags the file' do
      expect(call).to be true
      expect(lex_file.reload.error_message).to eq(described_class::MESSAGE_KEY)
    end

    it 'does not repeat the flag when the sweep is run again' do
      described_class.call(lex_file, lex_person, content)
      expect(described_class.call(lex_file, lex_person, content)).to be false
      expect(lex_file.reload.error_message).to eq(described_class::MESSAGE_KEY)
    end

    it 'keeps any error already recorded on the file' do
      lex_file.update!(error_message: 'undefined method for nil')
      call
      expect(lex_file.reload.error_message).to eq("undefined method for nil\n#{described_class::MESSAGE_KEY}")
    end
  end

  context 'when the bibliography section has no contentful list items' do
    # Entries that genuinely have nothing to migrate must not be flagged.
    let(:content) { '<p><font><a name="Bib.">על המחבר ויצירתו:</a></font></p><p>לא נמצאו מקורות.</p>' }

    it 'does not flag the file' do
      expect(call).to be false
      expect(lex_file.reload.error_message).to be_nil
    end
  end

  context 'when there is no bibliography section at all' do
    let(:content) { '<p>ביוגרפיה בלבד</p>' }

    it 'does not flag the file' do
      expect(call).to be false
      expect(lex_file.reload.error_message).to be_nil
    end
  end

  context 'when citations were migrated' do
    let(:content) { populated_bibliography }
    let(:lex_person) { create(:lex_person, citations: [build(:lex_citation)]) }

    it 'does not flag the file' do
      expect(call).to be false
      expect(lex_file.reload.error_message).to be_nil
    end
  end
end
