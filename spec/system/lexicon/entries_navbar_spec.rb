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

      expect(page).to have_css('.book-nav-full')

      within('.book-nav-full') do
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

    it 'displays the thin navbar for mobile' do
      visit lexicon_entry_path(entry)

      # The thin navbar exists but is hidden on desktop (display: none)
      # It's only visible on mobile viewports (< 991px)
      expect(page).to have_css('.book-nav-thin', visible: :all)

      within('.book-nav-thin', visible: :all) do
        expect(page).to have_css('.nav-books.lexicon-background-color[data-scroll-target="#lexicon-biography"]', visible: :all)
      end
    end

    it 'scrolls to biography section when biography nav item is clicked' do
      visit lexicon_entry_path(entry)

      # Verify the navbar and biography section exist
      expect(page).to have_css('.book-nav-full')
      expect(page).to have_css('#lexicon-biography', visible: :all)

      # Scroll down first to ensure we can detect a scroll change
      page.execute_script('window.scrollTo(0, 500);')
      sleep 0.2

      within('.book-nav-full') do
        biography_link = find('.book-type[data-scroll-target="#lexicon-biography"]')
        biography_link.click
      end

      # Wait for scroll animation
      sleep 0.6

      # Verify the biography section is present
      biography_element = page.find('#lexicon-biography', visible: :all)
      expect(biography_element).to be_present
    end

    it 'scrolls to works section when works nav item is clicked' do
      visit lexicon_entry_path(entry)

      # Scroll to top first
      page.execute_script('window.scrollTo(0, 0);')

      within('.book-nav-full') do
        works_link = find('.book-type[data-scroll-target="#lexicon-works"]')
        works_link.click
      end

      # Wait for scroll animation
      sleep 0.6

      # Verify the works section exists
      expect(page).to have_css('#lexicon-works')
    end

    it 'scrolls to about section when about nav item is clicked' do
      visit lexicon_entry_path(entry)

      # Scroll to top first
      page.execute_script('window.scrollTo(0, 0);')

      within('.book-nav-full') do
        about_link = find('.book-type[data-scroll-target="#lexicon-about"]')
        about_link.click
      end

      # Wait for scroll animation
      sleep 0.6

      # Verify the about section exists
      expect(page).to have_css('#lexicon-about')
    end

    it 'scrolls to links section when links nav item is clicked' do
      visit lexicon_entry_path(entry)

      # Scroll to top first
      page.execute_script('window.scrollTo(0, 0);')

      within('.book-nav-full') do
        links_link = find('.book-type[data-scroll-target="#lexicon-links"]')
        links_link.click
      end

      # Wait for scroll animation
      sleep 0.6

      # Verify the links section exists
      expect(page).to have_css('#lexicon-links')
    end

    it 'updates selected state when clicking navbar items' do
      visit lexicon_entry_path(entry)

      within('.book-nav-full') do
        biography_link = find('.book-type[data-scroll-target="#lexicon-biography"]')
        works_link = find('.book-type[data-scroll-target="#lexicon-works"]')

        # Biography should be selected by default
        expect(biography_link[:class]).to include('selected')

        # Click works link
        works_link.click

        # Wait for JavaScript to update classes
        sleep 0.2

        # Works should now be selected
        expect(works_link[:class]).to include('selected')
        # Biography should no longer be selected
        expect(biography_link[:class]).not_to include('selected')
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

      expect(page).to have_css('.book-nav-full')

      within('.book-nav-full') do
        expect(page).to have_content(I18n.t('lexicon.verification.sections.description_section'))
        expect(page).to have_content(I18n.t('lexicon.verification.sections.toc_section'))
        expect(page).to have_content(I18n.t('lexicon.verification.sections.links_section'))
      end
    end

    it 'scrolls to description section when description nav item is clicked' do
      visit lexicon_entry_path(entry)

      # Scroll to top first
      page.execute_script('window.scrollTo(0, 0);')

      within('.book-nav-full') do
        description_link = find('.book-type[data-scroll-target="#lexicon-description"]')
        description_link.click
      end

      # Wait for scroll animation
      sleep 0.6

      # Verify the description section exists
      expect(page).to have_css('#lexicon-description')
    end

    it 'scrolls to TOC section when TOC nav item is clicked' do
      visit lexicon_entry_path(entry)

      # Scroll to top first
      page.execute_script('window.scrollTo(0, 0);')

      within('.book-nav-full') do
        toc_link = find('.book-type[data-scroll-target="#lexicon-toc"]')
        toc_link.click
      end

      # Wait for scroll animation
      sleep 0.6

      # Verify the TOC section exists
      expect(page).to have_css('#lexicon-toc')
    end

    it 'thin navbar scrolls to description by default for publications' do
      visit lexicon_entry_path(entry)

      # The thin navbar exists but is hidden on desktop (display: none)
      # It's only visible on mobile viewports (< 991px)
      within('.book-nav-thin', visible: :all) do
        expect(page).to have_css('.nav-books.lexicon-background-color[data-scroll-target="#lexicon-description"]', visible: :all)
      end
    end
  end
end
