# frozen_string_literal: true

require 'rails_helper'

describe 'Lexicon Verification Auto-Matching', :js do
  before do
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

  describe 'Auto-matching works to publications' do
    # rubocop:disable RSpec/ExampleLength
    it 'shows proposed matches without persisting' do
      visit "/lex/verification/#{entry.id}"

      # Open the works modal
      within '#section-works' do
        click_button 'ערוך'
      end

      # Wait for modal to load
      expect(page).to have_css('#works-section', wait: 5)

      # Should show success message with count
      expect(page).to have_content(/הותאמו אוטומטית לפרסומים/)

      # Verify work1 shows proposed match (exact match)
      within "#publication-cell-#{work1.id}" do
        expect(page).to have_css('.proposed-match')
        expect(page).to have_content('Tmol Shilshom')
        expect(page).to have_css('.similarity-badge', text: '100%')
        expect(page).to have_css('.btn-confirm-match')
        expect(page).to have_css('.btn-reject-match')
      end

      # Verify work2 shows proposed match (after removing author name)
      within "#publication-cell-#{work2.id}" do
        expect(page).to have_css('.proposed-match')
        expect(page).to have_content('Agnon Shmuel Yosef / Sippur Pashut')
        expect(page).to have_css('.similarity-badge', text: '100%')
      end

      # Verify work3 shows proposed match despite typo (fuzzy match)
      within "#publication-cell-#{work3.id}" do
        expect(page).to have_css('.proposed-match')
        expect(page).to have_content('Tmol Shilshom')
        # Similarity should be high but not 100%
        badge = find('.similarity-badge')
        expect(badge.text.to_i).to be >= 70
      end

      # Verify work4 did not match (too different)
      within "#publication-cell-#{work4.id}" do
        expect(page).not_to have_css('.proposed-match')
      end

      # Close modal and verify database was NOT updated
      within '.modal-footer' do
        click_button 'סגירה'
      end
      expect(page).not_to have_css('#generalDlg.show', wait: 5)

      # Verify works were NOT persisted
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

    # rubocop:disable RSpec/ExampleLength
    it 'confirms match when user clicks confirm button' do
      visit "/lex/verification/#{entry.id}"

      # Open the works modal
      within '#section-works' do
        click_button 'ערוך'
      end

      expect(page).to have_css('#works-section', wait: 5)

      # Click confirm button for work1
      within "#publication-cell-#{work1.id}" do
        find('.btn-confirm-match').click
      end

      # Wait for AJAX to complete and page to reload
      expect(page).to have_css('#works-section', wait: 5)

      # Verify work1 now shows as linked (persisted)
      within "tr[data-work-id='#{work1.id}']" do
        expect(page).to have_link('Tmol Shilshom', href: publication_path(pub1))
      end

      # Verify collection was also set
      within "#collection-cell-#{work1.id}" do
        expect(page).to have_link('Tmol Shilshom Collection', href: collection_path(collection1))
      end

      # Close modal and verify database was updated
      within '.modal-footer' do
        click_button 'סגירה'
      end
      expect(page).not_to have_css('#generalDlg.show', wait: 5)

      work1.reload
      expect(work1.publication_id).to eq(pub1.id)
      expect(work1.collection_id).to eq(collection1.id)
    end
    # rubocop:enable RSpec/ExampleLength

    it 'rejects match when user clicks reject button' do
      visit "/lex/verification/#{entry.id}"

      # Open the works modal
      within '#section-works' do
        click_button 'ערוך'
      end

      expect(page).to have_css('#works-section', wait: 5)

      # Click reject button for work1
      within "#publication-cell-#{work1.id}" do
        find('.btn-reject-match').click
        # Capybara will wait for the proposed match to disappear
        expect(page).not_to have_css('.proposed-match')
      end

      # Close modal and verify database was NOT updated
      within '.modal-footer' do
        click_button 'סגירה'
      end
      expect(page).not_to have_css('#generalDlg.show', wait: 5)

      work1.reload
      expect(work1.publication_id).to be_nil
    end

    it 'does not propose matches for existing publication assignments' do
      # Manually assign work1 to a different publication
      other_pub = create(:publication, authority: authority, title: 'Other Publication')
      work1.update!(publication_id: other_pub.id)

      visit "/lex/verification/#{entry.id}"

      # Open the works modal
      within '#section-works' do
        click_button 'ערוך'
      end

      expect(page).to have_css('#works-section', wait: 5)

      # Verify work1 still has the original publication (no proposed match)
      within "tr[data-work-id='#{work1.id}']" do
        expect(page).to have_link('Other Publication', href: publication_path(other_pub))
        # Should NOT show proposed match
        expect(page).not_to have_css('.proposed-match')
      end

      # But work2 should still have proposed match
      within "#publication-cell-#{work2.id}" do
        expect(page).to have_css('.proposed-match')
        expect(page).to have_content('Agnon Shmuel Yosef / Sippur Pashut')
        expect(page).to have_css('.similarity-badge', text: '100%')
      end
    end

    it 'shows different similarity percentages for different match qualities' do
      visit "/lex/verification/#{entry.id}"

      within '#section-works' do
        click_button 'ערוך'
      end

      expect(page).to have_css('#works-section', wait: 5)

      # Exact match should show 100%
      within "#publication-cell-#{work1.id}" do
        expect(page).to have_css('.similarity-badge', text: '100%')
      end

      # Fuzzy match should show lower percentage (but still >= 70%)
      within "#publication-cell-#{work3.id}" do
        badge = find('.similarity-badge')
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
        click_button 'ערוך'
      end

      expect(page).to have_css('#works-section', wait: 5)

      # Should show warning about no authority
      expect(page).to have_css('.alert-warning')

      # Should NOT show auto-matching success message
      expect(page).not_to have_content(/הותאמו אוטומטית/)

      # Work should have no proposed match
      within "#publication-cell-#{work_no_auth.id}" do
        expect(page).not_to have_css('.proposed-match')
      end
    end
  end

  describe 'Similarity badge styling' do
    it 'displays similarity badge in proposed matches' do
      visit "/lex/verification/#{entry.id}"

      within '#section-works' do
        click_button 'ערוך'
      end

      expect(page).to have_css('#works-section', wait: 5)

      within "#publication-cell-#{work1.id}" do
        # Verify similarity badge exists in proposed match
        expect(page).to have_css('.similarity-badge', text: '100%')
      end
    end
  end
end
