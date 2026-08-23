# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Deleting a citation from the verification page', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
  end

  let(:entry) { create(:lex_entry, :person, status: :draft) }
  let(:person) { entry.lex_item }
  let!(:citation) { create(:lex_citation, person: person, title: 'מראה מקום שגוי') }
  let!(:other_citation) { create(:lex_citation, person: person, title: 'מראה מקום תקין') }

  def delete_button_for(target)
    within("#citation-#{target.id}") do
      find('a.delete-citation')
    end
  end

  it 'asks for confirmation and keeps the citation when the confirmation is dismissed' do
    visit lexicon_verification_path(entry)

    dismiss_confirm(I18n.t('lexicon.verification.migrated.delete_citation_confirm')) do
      delete_button_for(citation).click
    end

    expect(page).to have_css("#citation-#{citation.id}")
    expect(person.citations.reload).to include(citation)
  end

  it 'deletes the citation and reloads the page when the confirmation is accepted' do
    visit lexicon_verification_path(entry)

    accept_confirm(I18n.t('lexicon.verification.migrated.delete_citation_confirm')) do
      delete_button_for(citation).click
    end

    expect(page).to have_no_css("#citation-#{citation.id}", wait: 8)
    expect(page).to have_css("#citation-#{other_citation.id}")
    expect(person.citations.reload).to contain_exactly(other_citation)
  end
end
