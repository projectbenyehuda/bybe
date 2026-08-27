# frozen_string_literal: true

require 'rails_helper'

# The lexicon's editor is credited under the lexicon title everywhere the lexicon is
# introduced by name: the public entry page, the public entry list, and the lexicon
# block of an Authority TOC. The backend carries the same credit inline, in parentheses,
# inside the navbar title.
RSpec.describe 'Lexicon editor credit', type: :request do
  let(:credit) { I18n.t('lexicon.header.editor_credit') }

  def credit_lines(body)
    Nokogiri::HTML(body).css('.lexicon-editor-credit').map { |node| node.text.strip }
  end

  describe 'LexEntry#show' do
    let(:lex_entry) { create(:lex_entry, :person, status: 'published') }

    it 'credits the editor under the lexicon title' do
      get lexicon_entry_path(lex_entry)
      expect(credit_lines(response.body)).to eq([credit])
    end
  end

  describe 'the public entry list' do
    before { create(:lex_entry, :person, status: 'published') }

    it 'credits the editor under the list title' do
      get lexicon_entries_list_path
      expect(credit_lines(response.body)).to eq([credit])
    end
  end

  describe 'Authority#toc' do
    let(:uncollected_collection) { create(:collection, :uncollected) }
    let(:author) { create(:authority, :published, uncollected_works_collection: uncollected_collection) }

    before { author.update(lex_person: lex_entry.lex_item) }

    context 'when the authority has lexicon content' do
      let(:lex_entry) { create(:lex_entry, :person, status: 'published') }

      it 'credits the editor under the lexicon heading' do
        get authority_path(author)
        expect(credit_lines(response.body)).to eq([credit])
      end
    end

    context 'when every lexicon section is empty' do
      let(:lex_entry) { create(:lex_entry, :person, status: 'published', lex_item: create(:lex_person, bio: nil)) }

      # the lexicon heading itself is dropped in this case, and the credit goes with it
      it 'shows no credit' do
        get authority_path(author)
        expect(credit_lines(response.body)).to be_empty
      end
    end
  end

  describe 'the backend' do
    before { login_as_lexicon_editor }

    it 'credits the editor in parentheses inside the navbar title' do
      get lexicon_entries_path
      brand = Nokogiri::HTML(response.body).at_css('.navbar-brand').text.strip
      expect(brand).to eq(I18n.t('lexicon.layout.title', credit: credit))
      expect(brand).to include("(#{credit})")
    end
  end
end
