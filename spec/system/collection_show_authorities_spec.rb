# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Collection show page - authority display', :js, type: :system do
  before do
    Capybara.current_session.driver.browser if Capybara.current_session.driver.respond_to?(:browser)
  rescue StandardError
    skip 'WebDriver not available or misconfigured'
  end

  # Create authorities for each role
  let!(:author) { create(:authority, name: 'Author Name') }
  let!(:translator) { create(:authority, name: 'Translator Name') }
  let!(:illustrator) { create(:authority, name: 'Illustrator Name') }
  let!(:photographer) { create(:authority, name: 'Photographer Name') }
  let!(:designer) { create(:authority, name: 'Designer Name') }
  let!(:editor) { create(:authority, name: 'Editor Name') }
  let!(:contributor) { create(:authority, name: 'Contributor Name') }
  let!(:other_role) { create(:authority, name: 'Other Role Name') }

  let!(:collection) do
    Chewy.strategy(:atomic) do
      col = create(:collection, title: 'Test Collection')

      # Add all types of involved authorities
      create(:involved_authority, item: col, authority: author, role: 'author')
      create(:involved_authority, item: col, authority: translator, role: 'translator')
      create(:involved_authority, item: col, authority: illustrator, role: 'illustrator')
      create(:involved_authority, item: col, authority: photographer, role: 'photographer')
      create(:involved_authority, item: col, authority: designer, role: 'designer')
      create(:involved_authority, item: col, authority: editor, role: 'editor')
      create(:involved_authority, item: col, authority: contributor, role: 'contributor')
      create(:involved_authority, item: col, authority: other_role, role: 'other')

      col
    end
  end

  after do
    Chewy.massacre
  end

  describe 'displaying all involved authorities' do
    it 'shows all authority roles with proper labels and links' do
      visit collection_path(collection)

      # Wait for page to load
      expect(page).to have_css('.by-card-v02.work-info-card', wait: 10)

      within('.by-card-v02.work-info-card') do
        # Verify authors are displayed in headline-2-v02
        expect(page).to have_css('.headline-2-v02')
        within('.headline-2-v02') do
          expect(page).to have_link('Author Name', href: authority_path(author))

          # Verify translators are shown with correct label
          expect(page).to have_text(I18n.t('involved_authority.abstract_roles.translator'))
          expect(page).to have_link('Translator Name', href: authority_path(translator))
        end

        # Verify illustrators are displayed in headline-3-v02
        expect(page).to have_text(I18n.t('involved_authority.abstract_roles.illustrator'))
        expect(page).to have_link('Illustrator Name', href: authority_path(illustrator))

        # Verify photographers are displayed
        expect(page).to have_text(I18n.t('involved_authority.abstract_roles.photographer'))
        expect(page).to have_link('Photographer Name', href: authority_path(photographer))

        # Verify designers are displayed
        expect(page).to have_text(I18n.t('involved_authority.abstract_roles.designer'))
        expect(page).to have_link('Designer Name', href: authority_path(designer))

        # Verify editors are displayed
        expect(page).to have_text(I18n.t('involved_authority.abstract_roles.editor'))
        expect(page).to have_link('Editor Name', href: authority_path(editor))

        # Verify contributors are displayed
        expect(page).to have_text(I18n.t('involved_authority.abstract_roles.contributor'))
        expect(page).to have_link('Contributor Name', href: authority_path(contributor))

        # Verify other role is displayed
        expect(page).to have_text(I18n.t('involved_authority.abstract_roles.other'))
        expect(page).to have_link('Other Role Name', href: authority_path(other_role))
      end
    end
  end

  describe 'collection with only some authority roles' do
    let!(:minimal_collection) do
      Chewy.strategy(:atomic) do
        col = create(:collection, title: 'Minimal Collection')

        # Add only author and illustrator
        create(:involved_authority, item: col, authority: author, role: 'author')
        create(:involved_authority, item: col, authority: illustrator, role: 'illustrator')

        col
      end
    end

    it 'shows only the present authority roles' do
      visit collection_path(minimal_collection)

      expect(page).to have_css('.by-card-v02.work-info-card', wait: 10)

      within('.by-card-v02.work-info-card') do
        # Should have author
        expect(page).to have_link('Author Name', href: authority_path(author))

        # Should have illustrator
        expect(page).to have_text(I18n.t('involved_authority.abstract_roles.illustrator'))
        expect(page).to have_link('Illustrator Name', href: authority_path(illustrator))

        # Should NOT have translator label
        expect(page).not_to have_text(I18n.t('involved_authority.abstract_roles.translator'))

        # Should NOT have photographer label
        expect(page).not_to have_text(I18n.t('involved_authority.abstract_roles.photographer'))

        # Should NOT have designer label
        expect(page).not_to have_text(I18n.t('involved_authority.abstract_roles.designer'))

        # Should NOT have editor label
        expect(page).not_to have_text(I18n.t('involved_authority.abstract_roles.editor'))

        # Should NOT have contributor label
        expect(page).not_to have_text(I18n.t('involved_authority.abstract_roles.contributor'))
      end
    end
  end

  describe 'multiple authorities in same role' do
    let!(:second_author) { create(:authority, name: 'Second Author') }
    let!(:multi_author_collection) do
      Chewy.strategy(:atomic) do
        col = create(:collection, title: 'Multi-Author Collection')

        # Add multiple authors
        create(:involved_authority, item: col, authority: author, role: 'author')
        create(:involved_authority, item: col, authority: second_author, role: 'author')

        col
      end
    end

    it 'shows all authorities in the same role, separated by commas' do
      visit collection_path(multi_author_collection)

      expect(page).to have_css('.by-card-v02.work-info-card', wait: 10)

      # Both authors should be displayed
      expect(page).to have_link('Author Name', href: authority_path(author))
      expect(page).to have_link('Second Author', href: authority_path(second_author))

      # Verify they're in the same headline-2-v02 section
      within('.by-card-v02.work-info-card .headline-2-v02') do
        expect(page).to have_content('Author Name')
        expect(page).to have_content('Second Author')
      end
    end
  end
end
