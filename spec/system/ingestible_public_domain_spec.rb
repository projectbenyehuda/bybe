# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ingestible public domain intellectual property', :js, :system do
  let!(:public_domain_author) { create(:authority, name: 'Public Domain Author', intellectual_property: :public_domain) }
  let!(:copyrighted_author) { create(:authority, name: 'Copyrighted Author', intellectual_property: :copyrighted) }

  let!(:ingestible) do
    create(:ingestible,
           markdown: "&&& Test Work 1\n\nSome content here.\n\n&&& Test Work 2\n\nMore content here.",
           works_buffer: [
             { title: 'Test Work 1', content: 'Some content here.' },
             { title: 'Test Work 2', content: 'More content here.' }
           ].to_json,
           works_buffer_updated_at: Time.current,
           toc_buffer: "yes || Test Work 1 ||  || poetry || he || \nyes || Test Work 2 ||  || poetry || he || ")
  end

  before do
    login_as_catalog_editor
  end

  describe 'TOC copyright status display' do
    context 'when all involved authorities are public domain' do
      it 'shows public domain message instead of select dropdown' do
        # Set default authorities to public domain
        ingestible.update!(
          default_authorities: [
            { seqno: 1, authority_id: public_domain_author.id, authority_name: public_domain_author.name,
              role: 'author' }
          ].to_json
        )

        visit edit_ingestible_path(ingestible, tab: 'toc')

        # Click to open TOC modal
        click_button I18n.t('ingestible.included_works')

        # Wait for modal to load and content to appear
        expect(page).to have_css('#generalDlg', visible: true, wait: 5)
        expect(page).to have_content('Test Work 1', wait: 5)

        # Should show public domain message
        expect(page).to have_content(I18n.t('ingestible.all_authorities_public_domain'))
        # Should NOT have intellectual property select dropdowns
        expect(page).not_to have_select('intellectual_property')
      end
    end

    context 'when at least one authority is not public domain' do
      it 'shows select dropdown for intellectual property' do
        # Set default authorities to include copyrighted author
        ingestible.update!(
          default_authorities: [
            { seqno: 1, authority_id: copyrighted_author.id, authority_name: copyrighted_author.name,
              role: 'author' }
          ].to_json
        )

        visit edit_ingestible_path(ingestible, tab: 'toc')
        click_button I18n.t('ingestible.included_works')

        expect(page).to have_css('#generalDlg', visible: true, wait: 5)
        expect(page).to have_content('Test Work 1', wait: 5)

        # Should have the select dropdown (one for each work in TOC)
        expect(page).to have_select('intellectual_property', minimum: 1)
        # Should NOT show public domain message
        expect(page).not_to have_content(I18n.t('ingestible.all_authorities_public_domain'))
      end
    end

    context 'constituent text with different authorities than defaults' do
      it 'shows correct copyright status per individual text' do
        # Default is public domain, but Text Work 1 has copyrighted author
        text1_authorities = [
          { seqno: 1, authority_id: copyrighted_author.id, authority_name: copyrighted_author.name,
            role: 'author' }
        ].to_json
        ingestible.update!(
          toc_buffer: "yes || Test Work 1 || #{text1_authorities} || poetry || he || by_permission\nyes || Test Work 2 ||  || poetry || he || by_permission",
          default_authorities: [
            { seqno: 1, authority_id: public_domain_author.id, authority_name: public_domain_author.name,
              role: 'author' }
          ].to_json
        )

        visit edit_ingestible_path(ingestible, tab: 'toc')
        click_button I18n.t('ingestible.included_works')

        expect(page).to have_css('#generalDlg', visible: true, wait: 5)
        expect(page).to have_content('Test Work 1', wait: 5)
        expect(page).to have_content('Test Work 2', wait: 5)

        # Should have at least one select (for Test Work 1 with copyrighted author)
        expect(page).to have_select('intellectual_property', minimum: 1)
        # Should also have the public domain message (for Test Work 2 with public domain author)
        expect(page).to have_content(I18n.t('ingestible.all_authorities_public_domain'))
      end
    end

  end
end
