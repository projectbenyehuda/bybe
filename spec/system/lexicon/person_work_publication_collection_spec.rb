# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'LexPersonWork publication/collection pickers in edit modal', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
  end

  let!(:authority) { create(:authority, name: 'Test Author') }
  let!(:person) { create(:lex_person, authority: authority, birthdate: '1970', gender: :female) }

  let!(:entry) do
    create(:lex_entry, title: 'Test Author', lex_item: person, status: :draft)
  end

  let!(:lex_file) do
    file_path = Rails.root.join('tmp/test_pub_coll_author.php')
    File.write(file_path, '<html><body><h1>Test Author</h1></body></html>')
    create(:lex_file,
           lex_entry: entry,
           fname: 'test_pub_coll_author.php',
           full_path: file_path.to_s,
           status: :ingested,
           entrytype: :person)
  end

  # A publication of the authority that has no volume of its own.
  let!(:publication) { create(:publication, authority: authority, title: 'Bibliography Entry') }

  let!(:work) { create(:lex_person_work, person: person, work_type: :original, title: 'Some Work') }

  after { FileUtils.rm_f(Rails.root.join('tmp/test_pub_coll_author.php')) }

  # Opens the per-work edit modal from the entry edit page's Works tab.
  def open_work_edit_modal
    visit "/lex/entries/#{entry.id}/edit"
    find('#works_tab').click
    expect(page).to have_css('#works .edit-person-work', wait: 10)
    find("#work_#{work.id} .edit-person-work").click
    expect(page).to have_css('#generalDlg.show', wait: 5)
  end

  # A publication and its volume are two records describing one book, so naming either one in the
  # form fills in the other. The editor should only have to pick the book once.
  context 'when a publication and a volume are linked to each other' do
    let!(:linked_volume) do
      create(:collection, collection_type: :volume, title: 'Linked Volume',
                          publication: publication, authors: [authority])
    end

    it 'selects the volume when its publication is chosen' do
      open_work_edit_modal

      within '#generalDlg' do
        select 'Bibliography Entry', from: 'lex_person_work_publication_id'

        expect(page).to have_select('lex_person_work_collection_id', selected: 'Linked Volume')
      end
    end

    it 'selects the publication when its volume is chosen' do
      open_work_edit_modal

      within '#generalDlg' do
        select 'Linked Volume', from: 'lex_person_work_collection_id'

        expect(page).to have_select('lex_person_work_publication_id', selected: 'Bibliography Entry')
      end
    end
  end

  context 'when the chosen volume belongs to another authority\'s publication' do
    let!(:translators_volume) do
      create(:collection, collection_type: :volume, title: 'Translated Volume',
                          publication: create(:publication, authority: create(:authority), title: 'Not Offered'),
                          authors: [authority])
    end

    it 'leaves the publication picker alone, since that publication is not offered' do
      open_work_edit_modal

      within '#generalDlg' do
        select 'Translated Volume', from: 'lex_person_work_collection_id'

        expect(page).to have_select('lex_person_work_collection_id', selected: 'Translated Volume')
        expect(page).to have_select('lex_person_work_publication_id',
                                    selected: I18n.t('lexicon.person_works.form.select_publication'))
      end
    end
  end

  context 'when the chosen collection is not linked to any publication' do
    let!(:unlinked_volume) do
      create(:collection, collection_type: :volume, title: 'Unlinked Volume', publication: nil,
                          authors: [authority])
    end

    it 'keeps the collection selected after a publication is chosen, so both can be saved' do
      open_work_edit_modal

      within '#generalDlg' do
        select 'Unlinked Volume', from: 'lex_person_work_collection_id'
        select 'Bibliography Entry', from: 'lex_person_work_publication_id'

        expect(page).to have_select('lex_person_work_collection_id', selected: 'Unlinked Volume')
      end
    end
  end

  context 'when a volume is credited to the authority only through its volume_series' do
    let!(:series_volume) do
      create(:collection, collection_type: :volume, title: 'Volume In A Series', publication: nil, authors: [])
    end

    before do
      create(:collection, collection_type: :volume_series, title: 'The Trilogy',
                          authors: [authority], included_collections: [series_volume])
    end

    it 'offers the volume even though it has no involved_authorities of its own' do
      expect(series_volume.involved_authorities).to be_empty

      open_work_edit_modal

      within '#generalDlg' do
        expect(page).to have_select('lex_person_work_collection_id', with_options: ['Volume In A Series'])
        select 'Volume In A Series', from: 'lex_person_work_collection_id'
        expect(page).to have_select('lex_person_work_collection_id', selected: 'Volume In A Series')
      end
    end

    it 'does not offer the volume_series itself, which is not a volume' do
      open_work_edit_modal

      within '#generalDlg' do
        expect(page).to have_select('lex_person_work_collection_id', with_options: ['Volume In A Series'])
        expect(page).to have_no_select('lex_person_work_collection_id', with_options: ['The Trilogy'])
      end
    end
  end

  context 'when the chosen collection belongs to a different publication' do
    let!(:other_volume) do
      create(:collection, collection_type: :volume, title: 'Volume Of Another Publication',
                          publication: create(:publication, authority: create(:authority)),
                          authors: [authority])
    end

    it 'clears the collection, since that pairing cannot be saved' do
      open_work_edit_modal

      within '#generalDlg' do
        select 'Volume Of Another Publication', from: 'lex_person_work_collection_id'
        select 'Bibliography Entry', from: 'lex_person_work_publication_id'

        expect(page).to have_select('lex_person_work_collection_id',
                                    selected: I18n.t('lexicon.person_works.form.select_collection'))
      end
    end
  end
end
