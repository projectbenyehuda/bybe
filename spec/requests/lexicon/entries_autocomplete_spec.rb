# frozen_string_literal: true

require 'rails_helper'

describe '/lex/entries/autocomplete' do
  subject(:suggestions) do
    get '/lex/entries/autocomplete', params: params
    response.parsed_body
  end

  # A person and a book sharing a title: the whole point of the type suffix.
  let!(:person) { create(:lex_entry, :person, title: 'נתן אלתרמן') }
  let!(:publication) { create(:lex_entry, :publication, title: 'נתן אלתרמן') }
  let(:params) { { term: 'נתן' } }

  before do
    login_as_lexicon_editor
    Chewy.massacre
    import_and_await(LexEntriesAutocompleteIndex, LexEntry.all)
  end

  after { Chewy.massacre }

  it 'suffixes each suggestion label with the entry type' do
    expect(suggestions.pluck('label')).to contain_exactly('נתן אלתרמן (אדם)', 'נתן אלתרמן (כותר)')
  end

  it 'keeps the bare title as the value inserted into the field' do
    expect(suggestions.pluck('value')).to all(eq('נתן אלתרמן'))
  end

  it 'returns the entry ids' do
    expect(suggestions.pluck('id')).to contain_exactly(person.id.to_s, publication.id.to_s)
  end

  it 'does not leak the raw entry type alongside the label' do
    expect(suggestions.first.keys).to contain_exactly('id', 'label', 'value')
  end

  context 'when an entry has no discernible type' do
    let!(:person) { create(:lex_entry, title: 'נתן אלתרמן', status: :raw) }

    it 'falls back to the bare title' do
      expect(suggestions.pluck('label')).to include('נתן אלתרמן')
    end
  end

  context 'when filtering by entry type' do
    let(:params) { { term: 'נתן', entry_type: 'person' } }

    it 'still labels the surviving suggestion' do
      expect(suggestions.pluck('label')).to eq(['נתן אלתרמן (אדם)'])
    end
  end

  # An editor typing a name into a lookup field should not have to reproduce the pointing or
  # the punctuation of the entry they are reaching for. See Lexicon::NormalizeSearchText.
  describe 'punctuation- and diacritic-insensitive suggestions' do
    let!(:person) { create(:lex_entry, :person, title: title) }
    let!(:publication) { create(:lex_entry, :publication, title: 'ספר אחר') }
    let(:labels) { suggestions.pluck('value') }

    context 'with niqqud in the title' do
      let(:title) { 'אמונה אֵלון' }
      let(:params) { { term: 'אמונה אלון' } }

      it { expect(labels).to contain_exactly title }
    end

    context 'with a maqaf in the title' do
      let(:title) { 'בן־ציון בן־משה' }
      let(:params) { { term: 'בן ציון' } }

      it { expect(labels).to contain_exactly title }
    end

    context 'with gershayim in the title' do
      let(:title) { 'יואב כ״ץ' }
      let(:params) { { term: 'יואב כץ' } }

      it { expect(labels).to contain_exactly title }
    end

    context 'when the editor does type the punctuation' do
      let(:title) { 'יואב כ״ץ' }
      let(:params) { { term: 'יואב כ״ץ' } }

      it { expect(labels).to contain_exactly title }
    end
  end
end
