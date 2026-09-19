# frozen_string_literal: true

require 'rails_helper'

# The public lexicon list's name filter runs as a MySQL LIKE, so it used to match only when the
# visitor's punctuation and pointing happened to agree with the stored title. Each case below is
# asserted in both directions: the plain spelling has to find the marked-up entry, and the
# marked-up spelling has to keep finding it too.
describe '/lex/entries/list name filter' do
  subject(:titles_listed) do
    get lexicon_entries_list_path, params: { name_filter: name_filter }
    # The results partial renders each entry's title, so matching entries are the ones whose
    # title appears in the body.
    all_entries.select { |entry| response.body.include?(CGI.escapeHTML(entry.title)) }.map(&:title)
  end

  let!(:pointed) { create(:lex_entry, :person, status: :published, title: 'אמונה אֵלון') }
  let!(:maqaf) { create(:lex_entry, :person, status: :published, title: 'בן־ציון בן־משה (1943–2024)') }
  let!(:gershayim) { create(:lex_entry, :person, status: :published, title: 'יואב כ״ץ (1965)') }
  let!(:hyphen) { create(:lex_entry, :person, status: :published, title: 'משה בן-שאול') }
  let!(:unrelated) { create(:lex_entry, :person, status: :published, title: 'שרה לוי') }

  let(:all_entries) { [pointed, maqaf, gershayim, hyphen, unrelated] }

  context 'when the query omits niqqud the title carries' do
    let(:name_filter) { 'אמונה אלון' }

    it { is_expected.to contain_exactly pointed.title }
  end

  context 'when the query carries the niqqud' do
    let(:name_filter) { 'אמונה אֵלון' }

    it { is_expected.to contain_exactly pointed.title }
  end

  context 'when the query spaces a maqaf' do
    let(:name_filter) { 'בן ציון בן משה' }

    it { is_expected.to contain_exactly maqaf.title }
  end

  context 'when the query uses the maqaf' do
    let(:name_filter) { 'בן־ציון בן־משה' }

    it { is_expected.to contain_exactly maqaf.title }
  end

  context 'when the query spaces an ASCII hyphen' do
    let(:name_filter) { 'משה בן שאול' }

    it { is_expected.to contain_exactly hyphen.title }
  end

  context 'when the query omits gershayim the title carries' do
    let(:name_filter) { 'כץ' }

    it { is_expected.to contain_exactly gershayim.title }
  end

  context 'when the query carries the gershayim' do
    let(:name_filter) { 'כ״ץ' }

    it { is_expected.to contain_exactly gershayim.title }
  end

  context 'when the query matches nothing' do
    let(:name_filter) { 'לא קיים' }

    it { is_expected.to be_empty }
  end

  context 'when a maqaf would be swallowed rather than spaced' do
    let(:name_filter) { 'בןציון' }

    it 'does not match, since the maqaf separates two words rather than joining them' do
      expect(titles_listed).to be_empty
    end
  end

  # A query of nothing but strippable marks normalizes to '', and '%%' as a LIKE pattern would
  # match every entry -- so the filter would silently behave as though nothing had been typed.
  context 'when the query is nothing but marks the normalizer strips' do
    let(:name_filter) { '־' }

    it 'matches nothing rather than everything' do
      expect(titles_listed).to be_empty
    end
  end

  context 'when the query is nothing but gershayim' do
    let(:name_filter) { '״' }

    it { is_expected.to be_empty }
  end
end
