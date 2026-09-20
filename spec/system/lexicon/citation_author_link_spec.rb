# frozen_string_literal: true

require 'rails_helper'

# Pointing a plaintext citation author -- one no lexicon entry could be resolved for -- at an
# arbitrary URL, from the two places an editor works on citations: the migration verification
# workbench, and the citations tab of the entry editor.
RSpec.describe 'Linking a plaintext citation author to a URL', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
  end

  let!(:person) { create(:lex_person, gender: :female) }
  let!(:entry) { create(:lex_entry, title: 'חוה שפירא', lex_item: person, status: :draft) }
  let!(:citation) do
    create(:lex_citation, person: person, authors_count: 0, title: 'זרקור על דמות נעלמה', link: nil)
  end
  let!(:author) { create(:lex_citation_author, citation: citation, name: 'איזיקוביץ, גילי', link: nil) }

  let(:add_url_label) { I18n.t('lexicon.citation_authors.edit_link.add') }
  let(:edit_url_label) { I18n.t('lexicon.citation_authors.edit_link.edit') }

  describe 'from the verification workbench' do
    it 'offers the button next to a plaintext author and saves the URL it is given' do
      visit lexicon_verification_path(entry)

      within("#citation-#{citation.id}") do
        expect(page).to have_content('איזיקוביץ, גילי')
        click_button add_url_label
      end

      expect(page).to have_css('#generalDlg.show', wait: 5)
      within '#generalDlg' do
        fill_in 'lex_citation_author_link', with: 'https://example.com/gili'
        click_button I18n.t(:save)
      end

      # The page reloads on success, and the author now renders as a link to the URL just given
      within("#citation-#{citation.id}") do
        expect(page).to have_link('איזיקוביץ, גילי', href: 'https://example.com/gili', wait: 8)
        expect(page).to have_button(edit_url_label)
      end

      expect(author.reload.link).to eq('https://example.com/gili')
    end

    it 'reports a URL of a scheme it refuses instead of saving it' do
      visit lexicon_verification_path(entry)

      within("#citation-#{citation.id}") { click_button add_url_label }
      expect(page).to have_css('#generalDlg.show', wait: 5)

      within '#generalDlg' do
        fill_in 'lex_citation_author_link', with: 'javascript:alert(1)'
        click_button I18n.t(:save)

        expect(page).to have_content(
          I18n.t('activerecord.errors.models.lex_citation_author.attributes.link.invalid_url'), wait: 5
        )
      end

      expect(author.reload.link).to be_nil
    end

    context 'when the author is already linked to a lexicon entry' do
      let!(:author) do
        create(:lex_citation_author, citation: citation, name: nil, link: nil,
                                     entry: create(:lex_entry, :person, title: 'גילי איזיקוביץ'))
      end

      it 'offers no URL button, since a link may not coexist with an entry' do
        visit lexicon_verification_path(entry)

        within("#citation-#{citation.id}") do
          expect(page).to have_link('איזיקוביץ, גילי')
          expect(page).to have_no_button(add_url_label)
          expect(page).to have_no_button(edit_url_label)
        end
      end
    end
  end

  describe "from the entry editor's citations tab" do
    def open_citation_edit_modal
      visit "/lex/entries/#{entry.id}/edit"
      click_link_or_button I18n.t('lexicon.entries.edit.citations')
      expect(page).to have_css('#citations ul.citations-group', wait: 5)

      find('a.edit-citation').click
      expect(page).to have_css('#generalDlg.show', wait: 5)
      expect(page).to have_css("#citation_author_link_#{author.id}", wait: 5)
    end

    it 'saves a URL typed into the authors list' do
      open_citation_edit_modal

      fill_in "citation_author_link_#{author.id}", with: 'https://example.com/gili'
      within '.citation-author-link' do
        click_button I18n.t(:save)
      end

      # The list reloads itself in place, re-rendering the author as a link to its new URL
      expect(page).to have_css('#authors-list a[href="https://example.com/gili"]',
                               text: 'איזיקוביץ, גילי', wait: 5)
      expect(author.reload.link).to eq('https://example.com/gili')
    end

    context 'when the author already carries a URL' do
      let!(:author) do
        create(:lex_citation_author, citation: citation, name: 'איזיקוביץ, גילי', link: 'https://example.com/old')
      end

      it 'clears the link when the field is emptied' do
        open_citation_edit_modal

        expect(page).to have_field("citation_author_link_#{author.id}", with: 'https://example.com/old')
        fill_in "citation_author_link_#{author.id}", with: ''
        within '.citation-author-link' do
          click_button I18n.t(:save)
        end

        expect(page).to have_no_css('#authors-list a[href="https://example.com/old"]', wait: 5)
        expect(author.reload.link).to be_nil
      end
    end
  end
end
