# frozen_string_literal: true

require 'rails_helper'

describe 'Lexicon Verification Auto-Matching', :js do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
  end

  let!(:authority) { create(:authority, name: 'Agnon Shmuel Yosef') }
  let!(:person) do
    create(:lex_person,
           birthdate: '1888',
           deathdate: '1970',
           bio: '<p>Nobel Prize winner</p>',
           gender: :male,
           authority: authority)
  end

  let!(:entry) do
    create(:lex_entry,
           title: 'Agnon',
           lex_item: person,
           status: :draft)
  end

  let!(:lex_file) do
    file_path = Rails.root.join('tmp/test_agnon.php')
    File.write(file_path, '<html><body><h1>Agnon</h1></body></html>')

    create(:lex_file,
           lex_entry: entry,
           fname: 'test_agnon.php',
           full_path: file_path.to_s,
           status: :ingested,
           entrytype: :person)
  end

  # Publications for the authority
  let!(:pub1) do
    create(:publication,
           authority: authority,
           title: 'Tmol Shilshom')
  end

  let!(:pub2) do
    create(:publication,
           authority: authority,
           title: 'Agnon Shmuel Yosef / Sippur Pashut')
  end

  let!(:pub3) do
    create(:publication,
           authority: authority,
           title: 'Oreah Natah Lalun')
  end

  # Collection for pub1
  let!(:collection1) { create(:collection, publication: pub1, title: 'Tmol Shilshom Collection') }

  # Works without publication assignments
  let!(:work1) do
    create(:lex_person_work,
           person: person,
           title: 'Tmol Shilshom',
           work_type: :original,
           publication_id: nil,
           collection_id: nil)
  end

  let!(:work2) do
    create(:lex_person_work,
           person: person,
           title: 'Sippur Pashut',
           work_type: :original,
           publication_id: nil,
           collection_id: nil)
  end

  let!(:work3) do
    create(:lex_person_work,
           person: person,
           title: 'Tmol Shilsom', # Typo - should still match
           work_type: :original,
           publication_id: nil,
           collection_id: nil)
  end

  let!(:work4) do
    create(:lex_person_work,
           person: person,
           title: 'Unrelated Book',
           work_type: :original,
           publication_id: nil,
           collection_id: nil)
  end

  after do
    FileUtils.rm_f(lex_file.full_path)
  end

  def open_auto_match_modal
    within '#section-works' do
      click_button I18n.t('lexicon.verification.sections.auto_match_works_btn')
    end
    expect(page).to have_css('#generalDlg.show', wait: 5)
    expect(page).to have_css('.auto-match-works-modal', wait: 5)
  end

  describe 'Auto-matching works to publications' do
    # rubocop:disable RSpec/ExampleLength
    it 'shows proposed matches without persisting' do
      visit "/lex/verification/#{entry.id}"
      open_auto_match_modal

      # Should show auto-match intro text
      expect(page).to have_content(/הותאמו אוטומטית לפרסומים/)

      # work1 should have an exact match row
      expect(page).to have_css("#match-row-#{work1.id}")
      within "#match-row-#{work1.id}" do
        expect(page).to have_content('Tmol Shilshom')
        expect(page).to have_css('.badge', text: '100%')
        expect(page).to have_button(I18n.t('lexicon.verification.edit.confirm_match'))
      end

      # work2 should match pub2 (after stripping author name prefix)
      expect(page).to have_css("#match-row-#{work2.id}")
      within "#match-row-#{work2.id}" do
        expect(page).to have_content('Agnon Shmuel Yosef / Sippur Pashut')
        expect(page).to have_css('.badge', text: '100%')
      end

      # work3 should match despite the typo (fuzzy match)
      expect(page).to have_css("#match-row-#{work3.id}")
      within "#match-row-#{work3.id}" do
        expect(page).to have_content('Tmol Shilshom')
        badge = find('.badge')
        expect(badge.text.to_i).to be >= 70
      end

      # work4 should NOT have a match row (too different)
      expect(page).not_to have_css("#match-row-#{work4.id}")

      # Close without confirming
      find('button', text: I18n.t('lexicon.verification.sections.close')).click
      expect(page).not_to have_css('#generalDlg.show', wait: 5)

      # Verify no changes were persisted
      work1.reload
      work2.reload
      work3.reload
      work4.reload

      expect(work1.publication_id).to be_nil
      expect(work2.publication_id).to be_nil
      expect(work3.publication_id).to be_nil
      expect(work4.publication_id).to be_nil
    end
    # rubocop:enable RSpec/ExampleLength

    it 'confirms match when user clicks confirm button' do
      visit "/lex/verification/#{entry.id}"
      open_auto_match_modal

      # Confirm the match for work1
      within "#match-row-#{work1.id}" do
        find('button', text: I18n.t('lexicon.verification.edit.confirm_match')).click
      end

      # After confirmation the modal closes and the page reloads
      expect(page).to have_css('#section-works', wait: 10)

      # After reload, work1's card should display the linked publication and collection
      within "#work-#{work1.id}" do
        expect(page).to have_link('Tmol Shilshom')
        expect(page).to have_link('Tmol Shilshom Collection')
      end

      # Verify the database was updated
      work1.reload
      expect(work1.publication_id).to eq(pub1.id)
      expect(work1.collection_id).to eq(collection1.id)
    end

    it 'does not propose matches for existing publication assignments' do
      other_pub = create(:publication, authority: authority, title: 'Other Publication')
      work1.update!(publication_id: other_pub.id)

      visit "/lex/verification/#{entry.id}"
      open_auto_match_modal

      # work1 already has a publication — should not appear as a proposed match
      expect(page).not_to have_css("#match-row-#{work1.id}")

      # work2 should still have a proposed match
      expect(page).to have_css("#match-row-#{work2.id}")
      within "#match-row-#{work2.id}" do
        expect(page).to have_css('.badge', text: '100%')
      end
    end

    it 'shows different similarity percentages for different match qualities' do
      visit "/lex/verification/#{entry.id}"
      open_auto_match_modal

      # Exact match shows 100%
      within "#match-row-#{work1.id}" do
        expect(page).to have_css('.badge', text: '100%')
      end

      # Fuzzy match shows lower percentage (but still >= 70%)
      within "#match-row-#{work3.id}" do
        badge = find('.badge')
        percentage = badge.text.gsub('%', '').to_i
        expect(percentage).to be >= 70
        expect(percentage).to be < 100
      end
    end
  end

  describe 'Auto-matching after authority association' do
    let!(:person_no_auth) do
      create(:lex_person,
             birthdate: '1900',
             deathdate: '1980',
             bio: '<p>Test person</p>',
             gender: :male,
             authority: nil)
    end

    let!(:entry_no_auth) do
      create(:lex_entry,
             title: 'Test Person',
             lex_item: person_no_auth,
             status: :draft)
    end

    let!(:work_no_auth) do
      create(:lex_person_work,
             person: person_no_auth,
             title: 'Tmol Shilshom',
             work_type: :original,
             publication_id: nil)
    end

    it 'shows no proposed matches before authority is associated' do
      visit "/lex/verification/#{entry_no_auth.id}"

      within '#section-works' do
        click_button I18n.t('lexicon.verification.sections.auto_match_works_btn')
      end
      expect(page).to have_css('#generalDlg.show', wait: 5)

      # Should show the "no proposals" message when no authority is linked
      expect(page).to have_content(I18n.t('lexicon.verification.sections.no_auto_match_proposals'))

      # Should NOT show the auto-matching success intro text
      expect(page).not_to have_content(/הותאמו אוטומטית/)

      # The unmatched work should not appear as a proposed match row
      expect(page).not_to have_css("#match-row-#{work_no_auth.id}")
    end
  end

  describe 'Similarity badge styling' do
    it 'displays similarity badge in proposed matches' do
      visit "/lex/verification/#{entry.id}"
      open_auto_match_modal

      within "#match-row-#{work1.id}" do
        expect(page).to have_css('.badge', text: '100%')
      end
    end
  end
end
