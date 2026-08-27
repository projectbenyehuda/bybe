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
end
