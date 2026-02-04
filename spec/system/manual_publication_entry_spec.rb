# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Manual Publication Entry', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_bib_editor
    visit bib_pubs_by_authority_path
  end

  let(:user) { create(:user, :bib_workshop) }
  let(:authority) { create(:authority, bib_done: false) }
  let!(:manual_bib_source) do
    BibSource.find_or_create_by!(title: 'manual_entry', source_type: :manual_entry, status: :enabled)
  end

  def login_as_bib_editor
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    user
  end

  describe 'manual entry form' do
    it 'displays a toggle button for the manual entry form' do
      expect(page).to have_button(I18n.t(:toggle_manual_entry_form))
    end

    it 'shows the form when toggle button is clicked' do
      # Form should be hidden initially
      expect(page).to have_css('#manual-entry-form', visible: false)

      # Click toggle button
      click_button I18n.t(:toggle_manual_entry_form)

      # Form should be visible
      expect(page).to have_css('#manual-entry-form', visible: true)
      expect(page).to have_content(I18n.t(:manual_entry_form_header))
    end

    it 'hides the form when toggle button is clicked again' do
      click_button I18n.t(:toggle_manual_entry_form)
      expect(page).to have_css('#manual-entry-form', visible: true)

      click_button I18n.t(:toggle_manual_entry_form)
      expect(page).to have_css('#manual-entry-form', visible: false)
    end

    it 'has submit button disabled when no authority is selected' do
      click_button I18n.t(:toggle_manual_entry_form)
      submit_btn = find('#manual-submit-btn')
      expect(submit_btn).to be_disabled
    end
  end

  describe 'creating a manual publication' do
    before do
      # Select an authority first
      fill_in 'authority', with: authority.name
      # Simulate autocomplete selection
      page.execute_script("$('#authority_id').val(#{authority.id});")
      page.execute_script("$('#authority').trigger('railsAutocomplete.select', [{item: {id: #{authority.id}}}]);")

      # Open the manual entry form
      click_button I18n.t(:toggle_manual_entry_form)
    end

    it 'enables submit button when authority is selected' do
      submit_btn = find('#manual-submit-btn')
      expect(submit_btn).not_to be_disabled
    end

    context 'with valid required fields' do
      it 'creates a new publication with manual_entry bib_source and displays it in the publications list' do
        within '#manual-entry-form' do
          fill_in I18n.t(:title), with: 'Test Publication Title'
          fill_in I18n.t(:author), with: 'Test Author'
          fill_in I18n.t(:publisher), with: 'Test Publisher'
          fill_in I18n.t(:year_published), with: '1950'

          click_button I18n.t(:add_manual_publication)
        end

        # Wait for AJAX success - new publication should appear in #pubs
        expect(page).to have_css('#pubs', text: 'Test Publication Title', wait: 5)

        # Verify publication was created in database
        expect(Publication.count).to eq(1)

        publication = Publication.last
        expect(publication.title).to eq('Test Publication Title')
        expect(publication.author_line).to eq('Test Author')
        expect(publication.publisher_line).to eq('Test Publisher')
        expect(publication.pub_year).to eq('1950')
        expect(publication.authority_id).to eq(authority.id)
        expect(publication.bib_source.title).to eq('manual_entry')
        expect(publication.status).to eq('todo')

        # Verify the publication appears in the #pubs table
        within '#pubs' do
          expect(page).to have_content('Test Publication Title')
          expect(page).to have_content('Test Author')
          expect(page).to have_content('Test Publisher')
        end
      end

      it 'creates a holding for the publication' do
        within '#manual-entry-form' do
          fill_in I18n.t(:title), with: 'Test Publication'
          fill_in I18n.t(:author), with: 'Test Author'
          fill_in I18n.t(:publisher), with: 'Test Publisher'
          fill_in I18n.t(:year_published), with: '1950'

          click_button I18n.t(:add_manual_publication)
        end

        # Wait for AJAX success - new publication should appear
        expect(page).to have_css('#pubs', text: 'Test Publication', wait: 5)

        # Verify holding was created
        expect(Holding.count).to eq(1)
        holding = Holding.last
        expect(holding.bib_source.title).to eq('manual_entry')
        expect(holding.status).to eq('todo')
      end
    end

    context 'with optional fields filled' do
      it 'saves optional fields correctly' do
        within '#manual-entry-form' do
          fill_in I18n.t(:title), with: 'Test Publication'
          fill_in I18n.t(:author), with: 'Test Author'
          fill_in I18n.t(:publisher), with: 'Test Publisher'
          fill_in I18n.t(:year_published), with: '1950'
          fill_in I18n.t(:language), with: 'Hebrew'
          fill_in I18n.t(:record_source), with: 'https://example.com/record/123'
          fill_in I18n.t(:location), with: 'Shelf A-42'
          fill_in I18n.t(:comments), with: 'Test notes about this publication'

          click_button I18n.t(:add_manual_publication)
        end

        # Wait for AJAX success - new publication should appear
        expect(page).to have_css('#pubs', text: 'Test Publication', wait: 5)

        publication = Publication.last
        expect(publication.language).to eq('Hebrew')
        expect(publication.source_id).to eq('https://example.com/record/123')
        expect(publication.notes).to eq('Test notes about this publication')

        holding = Holding.last
        expect(holding.location).to eq('Shelf A-42')
      end
    end

    context 'without selecting an authority first' do
      it 'disables the submit button and prevents form submission' do
        visit bib_pubs_by_authority_path
        click_button I18n.t(:toggle_manual_entry_form)

        within '#manual-entry-form' do
          # Submit button should be disabled
          submit_btn = find('#manual-submit-btn')
          expect(submit_btn).to be_disabled

          # Try to fill the form
          fill_in I18n.t(:title), with: 'Test Publication'
          fill_in I18n.t(:author), with: 'Test Author'
          fill_in I18n.t(:publisher), with: 'Test Publisher'
          fill_in I18n.t(:year_published), with: '1950'

          # Button should still be disabled
          expect(submit_btn).to be_disabled
        end

        # The publication should not be created
        publication = Publication.find_by(title: 'Test Publication')
        expect(publication).to be_nil
      end
    end
  end
end
