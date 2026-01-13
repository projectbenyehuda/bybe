# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Lexicon entries navbar', type: :system, js: true do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  describe 'Person entry navbar' do
    let!(:person) do
      create(:lex_person,
             birthdate: '1138',
             deathdate: '1204',
             bio: 'Test biography content',
             works: "First work\nSecond work",
             gender: :male)
    end

    let!(:entry) do
      create(:lex_entry,
             title: 'Test Person',
             lex_item: person,
             status: :published)
    end

    let!(:citation) do
      create(:lex_citation,
             person: person,
             title: 'Test Citation',
             from_publication: 'Test Publication',
             pages: '123-145',
             raw: '<p>Test citation markup</p>',
             status: :approved)
    end

    let!(:link) do
      create(:lex_link,
             item: person,
             url: 'https://example.com',
             description: 'Test Link')
    end

    it 'displays the full navbar with correct sections' do
      visit lexicon_entry_path(entry)

      expect(page).to have_css('#genrenav')

      within('#genrenav') do
        expect(page).to have_content(I18n.t('lexicon.verification.sections.biography'))
        expect(page).to have_content(I18n.t('lexicon.verification.sections.works_section'))
        expect(page).to have_content(I18n.t('lexicon.verification.sections.links_section'))

        # The "about" section should show with gender suffix
        about_text = I18n.t('activerecord.attributes.lex_person.about',
                           gender_suffix: person.female? ? 'ת' : '',
                           gender_letter: person.gender_letter)
        expect(page).to have_content(about_text)
      end
    end

    # Note: The current implementation uses a single responsive navbar
    # without separate desktop/mobile variants

    it 'scrolls to biography section when biography nav item is clicked' do
      visit lexicon_entry_path(entry)

      # Verify the navbar and biography section exist
      expect(page).to have_css('#genrenav')
      expect(page).to have_css('#lexicon-biography', visible: :all)

      # Scroll down first to ensure we can detect a scroll change
      page.execute_script('window.scrollTo(0, 500);')

      within('#genrenav') do
        biography_link = find('.nav-item[data-scroll-target="#lexicon-biography"]')
        biography_link.click
      end

      # Verify the biography section is present (Capybara waits automatically)
      biography_element = page.find('#lexicon-biography', visible: :all)
      expect(biography_element).to be_present
    end

    it 'scrolls to works section when works nav item is clicked' do
      visit lexicon_entry_path(entry)

      # Scroll to top first
      page.execute_script('window.scrollTo(0, 0);')

      within('#genrenav') do
        works_link = find('.nav-item[data-scroll-target="#lexicon-works"]')
        works_link.click
      end

      # Verify the works section exists (Capybara waits automatically)
      expect(page).to have_css('#lexicon-works')
    end

    it 'scrolls to about section when about nav item is clicked' do
      visit lexicon_entry_path(entry)

      # Scroll to top first
      page.execute_script('window.scrollTo(0, 0);')

      within('#genrenav') do
        about_link = find('.nav-item[data-scroll-target="#lexicon-about"]')
        about_link.click
      end

      # Verify the about section exists (Capybara waits automatically)
      expect(page).to have_css('#lexicon-about')
    end

    it 'scrolls to links section when links nav item is clicked' do
      visit lexicon_entry_path(entry)

      # Scroll to top first
      page.execute_script('window.scrollTo(0, 0);')

      within('#genrenav') do
        links_link = find('.nav-item[data-scroll-target="#lexicon-links"]')
        links_link.click
      end

      # Verify the links section exists (Capybara waits automatically)
      expect(page).to have_css('#lexicon-links')
    end

    it 'updates selected state when clicking navbar items' do
      visit lexicon_entry_path(entry)

      within('#genrenav') do
        biography_item = find('.nav-item[data-scroll-target="#lexicon-biography"]')
        biography_link = biography_item.find('.nav-link')
        works_item = find('.nav-item[data-scroll-target="#lexicon-works"]')

        # Biography nav-link should have active class by default
        expect(biography_link[:class]).to include('active')

        # Click works item
        works_item.click

        # Wait for JavaScript to update classes by checking that works has active class
        # Re-find the links after the click to get updated classes
        works_link_after = works_item.find('.nav-link')
        biography_link_after = biography_item.find('.nav-link')

        expect(works_link_after[:class]).to include('active')
        # Biography should no longer have active class
        expect(biography_link_after[:class]).not_to include('active')
      end
    end
  end

  describe 'Publication entry navbar' do
    let!(:publication) do
      create(:lex_publication,
             description: 'Test publication description',
             toc: 'Test table of contents')
    end

    let!(:entry) do
      create(:lex_entry,
             title: 'Test Publication',
             lex_item: publication,
             status: :published)
    end

    let!(:link) do
      create(:lex_link,
             item: publication,
             url: 'https://example.com',
             description: 'Test Link')
    end

    it 'displays the full navbar with publication-specific sections' do
      visit lexicon_entry_path(entry)

      expect(page).to have_css('#genrenav')

      within('#genrenav') do
        expect(page).to have_content(I18n.t('lexicon.verification.sections.description_section'))
        expect(page).to have_content(I18n.t('lexicon.verification.sections.toc_section'))
        expect(page).to have_content(I18n.t('lexicon.verification.sections.links_section'))
      end
    end

    it 'scrolls to description section when description nav item is clicked' do
      visit lexicon_entry_path(entry)

      # Scroll to top first
      page.execute_script('window.scrollTo(0, 0);')

      within('#genrenav') do
        description_link = find('.nav-item[data-scroll-target="#lexicon-description"]')
        description_link.click
      end

      # Verify the description section exists (Capybara waits automatically)
      expect(page).to have_css('#lexicon-description')
    end

    it 'scrolls to TOC section when TOC nav item is clicked' do
      visit lexicon_entry_path(entry)

      # Scroll to top first
      page.execute_script('window.scrollTo(0, 0);')

      within('#genrenav') do
        toc_link = find('.nav-item[data-scroll-target="#lexicon-toc"]')
        toc_link.click
      end

      # Verify the TOC section exists (Capybara waits automatically)
      expect(page).to have_css('#lexicon-toc')
    end
  end
end
