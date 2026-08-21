# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Deleting a link from the verification page', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
  end

  let(:entry) { create(:lex_entry, :person, status: :draft) }
  let(:person) { entry.lex_item }
  let!(:link) { create(:lex_link, item: person, url: 'https://example.com/doomed') }
  let!(:other_link) { create(:lex_link, item: person, url: 'https://example.com/keeper') }

  def delete_button_for(target)
    within("#link-#{target.id}") do
      find('a.delete-link')
    end
  end

  it 'asks for confirmation and keeps the link when the confirmation is dismissed' do
    visit lexicon_verification_path(entry)

    dismiss_confirm(I18n.t('lexicon.verification.migrated.delete_link_confirm')) do
      delete_button_for(link).click
    end

    expect(page).to have_css("#link-#{link.id}")
    expect(person.links.reload).to include(link)
  end

  it 'deletes the link and reloads the page when the confirmation is accepted' do
    visit lexicon_verification_path(entry)

    accept_confirm(I18n.t('lexicon.verification.migrated.delete_link_confirm')) do
      delete_button_for(link).click
    end

    expect(page).to have_no_css("#link-#{link.id}", wait: 8)
    expect(page).to have_css("#link-#{other_link.id}")
    expect(person.links.reload).to contain_exactly(other_link)
  end
end
