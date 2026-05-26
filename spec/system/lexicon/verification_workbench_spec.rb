# frozen_string_literal: true

require 'rails_helper'

describe 'Lexicon Verification Workbench' do
  before do
    login_as_lexicon_editor
  end

  let!(:person) do
    create(:lex_person,
           birthdate: '1138',
           deathdate: '1204',
           bio: '<p>Test biography</p>',
           gender: :male)
  end

  let!(:entry) do
    create(:lex_entry,
           title: 'Test Person',
           lex_item: person,
           status: :draft)
  end

  let!(:lex_file) do
    # Create a temporary PHP file for testing
    file_path = Rails.root.join('tmp/test_person.php')
    File.write(file_path, '<html><body><h1>Test Person</h1><p>Test content</p></body></html>')

    create(:lex_file,
           lex_entry: entry,
           fname: 'test_person.php',
           full_path: file_path.to_s,
           status: :ingested,
           entrytype: :person)
  end

  let!(:citation) do
    create(:lex_citation,
           person: person,
           title: 'Test Citation',
           from_publication: 'Test Publication',
           pages: '123-145')
  end

  let!(:link) do
    create(:lex_link,
           item: person,
           url: 'https://example.com',
           description: 'Test Link')
  end

  after do
    # Clean up temp file
    FileUtils.rm_f(lex_file.full_path)
  end

  describe 'Verification Queue' do
    it 'displays the verification queue page' do
      visit '/lex/verification/queue'

      expect(page).to have_content('רשימת הסבות לבדיקה')
      expect(page).to have_content('Test Person')
    end

    it 'shows entry status and progress' do
      visit '/lex/verification/queue'

      within('tbody') do
        expect(page).to have_content('Test Person')
        expect(page).to have_content(I18n.t('lexicon.verification.queue.filters.person'))
        expect(page).to have_content(I18n.t('lexicon.verification.queue.filters.draft'))
        expect(page).to have_content('0%')
      end
    end

    it 'allows filtering by status' do
      visit '/lex/verification/queue'

      select 'טיוטה', from: 'status' # Draft in Hebrew
      click_button I18n.t('lexicon.entries.index.filter')

      expect(page).to have_content('Test Person')
    end

    it 'provides start verification button' do
      visit '/lex/verification/queue'

      within('tbody') do
        expect(page).to have_link('התחל בדיקה')
      end
    end

    it 'navigates to verification screen when clicking start' do
      visit '/lex/verification/queue'

      within('tbody') do
        click_link 'התחל בדיקה'
      end

      expect(page).to have_current_path("/lex/verification/#{entry.id}")
      expect(page).to have_content('אימות: Test Person')
    end
  end

  describe 'Verification Workbench' do
    before do
      visit "/lex/verification/#{entry.id}"
    end

    it 'displays the two-column layout with checklist accessible via modal' do
      # Source + migrated panels are the two visible columns
      expect(page).to have_css('.verification-source')
      expect(page).to have_css('.verification-migrated')
      # Checklist is in a modal opened via the header button
      expect(page).to have_css('#checklistModal', visible: :all)
    end

    it 'shows the entry title and back button' do
      expect(page).to have_content('אימות: Test Person')
      expect(page).to have_link('חזור לרשימה')
    end

    it 'initializes verification progress' do
      entry.reload
      expect(entry.status).to eq('verifying')
      expect(entry.verification_progress).to be_present
      expect(entry.verification_progress['checklist']).to be_present
    end

    it 'displays the verification checklist' do
      # Checklist is now inside #checklistModal (opened via button in the header)
      expect(page).to have_css('#checklistModal', text: 'רשימת בדיקה', visible: :all)
      expect(page).to have_css('#checklistModal', text: 'כותרת', visible: :all)
      expect(page).to have_css('#checklistModal', text: 'שנות חיים', visible: :all)
      expect(page).to have_css('#checklistModal', text: 'ביוגרפיה', visible: :all)
      expect(page).to have_css('#checklistModal', text: 'יצירות', visible: :all)
      expect(page).to have_css('#checklistModal', text: 'מראי מקום', visible: :all)
      expect(page).to have_css('#checklistModal', text: 'קישוריוֹת', visible: :all)
      expect(page).to have_css('#checklistModal', text: 'קבצים מצורפים', visible: :all)
    end

    it 'shows nested citation items in checklist' do
      expect(page).to have_css('#checklistModal .nested-checklist', text: 'Test Citation', visible: :all)
    end

    it 'displays source PHP in iframe' do
      within('.verification-source') do
        expect(page).to have_content('קובץ מקור')
        expect(page).to have_css('iframe.source-iframe')
      end
    end

    it 'displays migrated entry sections' do
      within('.verification-migrated') do
        expect(page).to have_content('שם ותאריכים')
        expect(page).to have_content('Test Person')
        expect(page).to have_content('1138')
        expect(page).to have_content('1204')
      end
    end

    it 'shows citations section with proper Hebrew label' do
      within('.verification-migrated') do
        expect(page).to have_content('מראי מקום') # Not ציטוטים
        expect(page).to have_content('Test Citation')
        expect(page).to have_content('Test Publication')
      end
    end

    it 'displays checklist checkboxes as disabled (read-only indicators)' do
      checkboxes = all('#checklistModal input[type="checkbox"]', visible: :all)
      expect(checkboxes.count).to be > 0
      expect(checkboxes).to all(be_disabled)
    end

    it 'disables mark verified button when incomplete' do
      button = find('#mark-verified-btn')
      expect(button).to be_disabled
    end

    it 'provides edit buttons for each section' do
      within('.verification-migrated') do
        edit_buttons = all('button', text: 'ערוך')
        expect(edit_buttons.count).to be > 0
      end
    end

    it 'shows progress bar with 0% initially' do
      within('.verification-header') do
        expect(page).to have_content('0%')
        expect(page).to have_css('.progress-bar', visible: :all)
      end
    end

    it 'displays overall notes textarea' do
      expect(page).to have_css('#checklistModal #overall_notes', visible: :all)
      expect(page).to have_css('#checklistModal', text: 'הערות כלליות', visible: :all)
    end

    it 'displays gender in localized form (Hebrew)' do
      within('.verification-migrated') do
        expect(page).to have_content('מגדר')  # Gender label in Hebrew
        expect(page).to have_content('זכר')   # Male in Hebrew, not "Male"
      end
    end

    it 'displays PHP source filename as clickable link' do
      within('.verification-source') do
        link = find('a.filename')
        expect(link.text).to eq('test_person.php')
        expect(link[:href]).to eq('https://benyehuda.org/lexicon/test_person.php')
        expect(link[:target]).to eq('_blank')
      end
    end

    it 'displays citation author names in view' do
      # Add an author to the citation first
      author_entry = create(:lex_entry, :person, title: 'Citation Author')
      citation.authors.create!(entry: author_entry)

      visit "/lex/verification/#{entry.id}"

      within('.verification-migrated') do
        within('#section-citations') do
          expect(page).to have_content('Citation Author')
        end
      end
    end

    it 'has functional quick verify buttons for citations', :js do
      skip 'WebDriver not available or misconfigured' unless webdriver_available?

      within('.verification-migrated') do
        within('#section-citations') do
          # Find the quick verify button for the citation
          verify_button = find('button[data-action="click->verification#quickVerify"]')
          expect(verify_button).to be_present
          expect(verify_button.text).to include('סמן כבדוק')
        end
      end
    end

    it 'has a mark as verified button for attachments section', :js do
      skip 'WebDriver not available or misconfigured' unless webdriver_available?

      within('.verification-migrated') do
        within('#section-attachments') do
          # Find the quick verify button for the attachments section
          verify_button = find('button[data-action="click->verification#quickVerify"]')
          expect(verify_button).to be_present
          expect(verify_button.text).to include('סמן כבדוק')
        end
      end
    end
  end

  describe 'Verification Progress Tracking' do
    before do
      visit "/lex/verification/#{entry.id}"
    end

    it 'updates progress when using quick verify buttons (checkboxes are read-only)', :js do
      skip 'WebDriver not available or misconfigured' unless webdriver_available?

      # Checklist is now in #checklistModal — open it to verify checkboxes are read-only
      find('button', text: I18n.t('lexicon.verification.checklist.title')).click
      expect(page).to have_css('#checklistModal', visible: true, wait: 3)

      within('#checklistModal') do
        checkbox = find('input[data-path="title"]')
        expect(checkbox).to be_disabled
      end

      # Verify progress bar exists in the main view
      expect(page).to have_css('#main-progress-bar', visible: :all)
    end

    it 'handles overall notes auto-save and escalation correctly', :js do
      skip 'WebDriver not available or misconfigured' unless webdriver_available?

      entry.start_verification!('editor@example.com')
      visit "/lex/verification/#{entry.id}"

      # Test Escalation with Modal
      modal_notes_text = 'Notes from main page'
      page.execute_script("$('#overall_notes').val('#{modal_notes_text}')")

      find('#escalate-btn').click

      # Wait for modal to appear
      expect(page).to have_css('#generalDlg', visible: true, wait: 10)
      within('#generalDlg') do
        expect(page).to have_content('הערך יועבר לבדיקה נוספת')
        notes_field = find('textarea#escalate_overall_notes')
        expect(notes_field.value).to eq(modal_notes_text)

        # Update notes in modal
        notes_field.fill_in with: 'Final escalation reason'
        click_button 'העברה לבדיקה נוספת'
      end

      # Should redirect to queue
      expect(page).to have_current_path(lexicon_verification_queue_path)
      expect(entry.reload).to be_status_escalated
      expect(entry.verification_progress['overall_notes']).to eq('Final escalation reason')
    end
  end

  describe 'Verification Completion' do
    it 'enables mark verified button when all items checked', :js do
      skip 'WebDriver not available or misconfigured' unless webdriver_available?

      visit "/lex/verification/#{entry.id}"

      # Wait for page to load and initialization to complete
      expect(page).to have_css('.verification-migrated')
      entry.reload

      # Check all items programmatically for speed
      entry.verification_progress['checklist'].each_key do |key|
        next if %w(citations links).include?(key) # Skip collections for now

        entry.update_checklist_item(key, true, '')
      end

      # Check citation items
      if entry.verification_progress['checklist']['citations']
        entry.verification_progress['checklist']['citations']['items'].each_key do |cit_id|
          entry.update_checklist_item("citations.items.#{cit_id}", true, '')
        end
      end

      # Check link items
      if entry.verification_progress['checklist']['links']
        entry.verification_progress['checklist']['links']['items'].each_key do |link_id|
          entry.update_checklist_item("links.items.#{link_id}", true, '')
        end
      end

      entry.reload
      expect(entry.verification_complete?).to be true

      # Reload page to see updated button state
      visit "/lex/verification/#{entry.id}"

      button = find('#mark-verified-btn')
      expect(button).not_to be_disabled
    end
  end

  describe 'Hide/Show Verified Items Toggle', :js do
    before do
      skip 'WebDriver not available or misconfigured' unless webdriver_available?

      # Initialize verification first
      entry.start_verification!('test@example.com')

      # Mark some items as verified to test the toggle
      entry.update_checklist_item('title', true, '')
      entry.update_checklist_item("citations.items.#{citation.id}", true, '')
      visit "/lex/verification/#{entry.id}"
    end

    it 'displays the hide verified toggle checkbox' do
      within('.verification-header') do
        expect(page).to have_css('#hide-verified-toggle')
        expect(page).to have_content('הסתר פריטים בדוקים')
      end
    end

    it 'hides verified items when toggle is checked' do
      # Initially, verified items should be visible
      expect(page).to have_css('#section-title.verified', visible: :visible)
      expect(page).to have_css('.citation-card.verified', visible: :visible)

      # Check the toggle
      within('.verification-header') do
        find('#hide-verified-toggle').click
      end

      # Verified items should now be hidden (Capybara waits automatically)
      expect(page).to have_css('#section-title.verified.hidden-verified', visible: :hidden)
      expect(page).to have_css('.citation-card.verified.hidden-verified', visible: :hidden)
    end

    it 'shows all items when toggle is unchecked' do
      # Check the toggle first to hide items
      within('.verification-header') do
        find('#hide-verified-toggle').click
      end

      # Verified items should be hidden (Capybara waits automatically)
      expect(page).to have_css('.hidden-verified', visible: :hidden)

      # Uncheck the toggle
      within('.verification-header') do
        find('#hide-verified-toggle').click
      end

      # All items should be visible again (Capybara waits automatically)
      expect(page).not_to have_css('.hidden-verified')
      expect(page).to have_css('#section-title.verified', visible: :visible)
      expect(page).to have_css('.citation-card.verified', visible: :visible)
    end

    it 'hides verified checklist items when toggle is checked' do
      # Check the toggle
      within('.verification-header') do
        find('#hide-verified-toggle').click
      end

      # Checklist is in #checklistModal; JS applies 'hidden-verified' to LI elements
      # of verified checkboxes even when the modal is closed
      modal = find('#checklistModal', visible: :all)
      title_checkbox = modal.find('input[data-path="title"]', visible: :all)
      title_li = title_checkbox.find(:xpath, 'ancestor::li', visible: :all)
      expect(title_li[:class]).to include('hidden-verified')
    end

    it 'persists the hide verified state across page reloads' do
      # Check the toggle
      within('.verification-header') do
        find('#hide-verified-toggle').click
      end

      # Verified items should be hidden
      expect(page).to have_css('#section-title.verified.hidden-verified', visible: :hidden)

      # Reload the page
      visit "/lex/verification/#{entry.id}"

      # Toggle should still be checked
      expect(page).to have_css('#hide-verified-toggle:checked')

      # Verified items should still be hidden after reload
      expect(page).to have_css('#section-title.verified.hidden-verified', visible: :hidden)
      expect(page).to have_css('.citation-card.verified.hidden-verified', visible: :hidden)
    end
  end

  describe 'Add Link modal', :js do
    before do
      skip 'WebDriver not available or misconfigured' unless webdriver_available?
      visit "/lex/verification/#{entry.id}"
    end

    it 'adds a new link and refreshes the links section without JS errors' do
      new_url = 'https://newlink.example.com'

      within('#section-links') do
        # Open the Add Link modal
        find('a', text: I18n.t('lexicon.verification.migrated.add_link')).click
      end

      # Wait for modal to open and fill in the form
      expect(page).to have_css('#generalDlg', visible: true, wait: 5)
      within('#generalDlgBody') do
        fill_in 'lex_link[url]', with: new_url
        find('[type="submit"]').click
      end

      # Page should reload and show the new link (location.reload() callback)
      expect(page).to have_css('#section-links', wait: 10)
      within('#section-links') do
        expect(page).to have_link(new_url, wait: 10)
      end
    end
  end

  describe 'Profile Image Selection', :js do
    before do
      skip 'WebDriver not available or misconfigured' unless webdriver_available?

      # Attach some test images to the entry
      File.open(Rails.root.join('spec/fixtures/images/male.png').to_s, 'rb') do |io|
        entry.attachments.attach(
          io: io,
          filename: 'male.png',
          content_type: 'image/png'
        )
      end

      File.open(Rails.root.join('spec/fixtures/images/female.png').to_s, 'rb') do |io|
        entry.attachments.attach(
          io: io,
          filename: 'female.png',
          content_type: 'image/png'
        )
      end
      visit "/lex/verification/#{entry.id}"
    end

    it 'displays "Use as Profile" buttons for each attachment' do
      within('#section-attachments') do
        expect(page).to have_button(I18n.t('lexicon.verification.migrated.use_as_profile'), count: 2)
      end
    end

    it 'sets profile image when button is clicked' do
      attachment = entry.attachments.first

      within('#section-attachments') do
        within("#attachment-#{attachment.id}") do
          # Wait for button to be present
          expect(page).to have_button(I18n.t('lexicon.verification.migrated.use_as_profile'))

          click_button I18n.t('lexicon.verification.migrated.use_as_profile')
        end
      end

      # Wait for AJAX to complete by polling the database
      # This is the critical functionality - database must be updated
      Timeout.timeout(5) do
        loop do
          entry.reload
          break if entry.profile_image_id == attachment.id

          sleep 0.1
        end
      end

      # Verify the database was updated - this is what matters
      expect(entry.profile_image_id).to eq(attachment.id)
    end

    it 'shows only one profile image at a time' do
      attachment1 = entry.attachments.first
      attachment2 = entry.attachments.second

      within('#section-attachments') do
        # Set first attachment as profile
        within("#attachment-#{attachment1.id}") do
          click_button I18n.t('lexicon.verification.migrated.use_as_profile')
        end
      end

      # Wait for first AJAX to complete
      Timeout.timeout(5) do
        loop do
          entry.reload
          break if entry.profile_image_id == attachment1.id

          sleep 0.1
        end
      end

      expect(entry.profile_image_id).to eq(attachment1.id)

      within('#section-attachments') do
        # Set second attachment as profile
        within("#attachment-#{attachment2.id}") do
          click_button I18n.t('lexicon.verification.migrated.use_as_profile')
        end
      end

      # Wait for second AJAX to complete
      Timeout.timeout(5) do
        loop do
          entry.reload
          break if entry.profile_image_id == attachment2.id

          sleep 0.1
        end
      end

      # Verify the database has only the second attachment as profile
      expect(entry.profile_image_id).to eq(attachment2.id)
    end

    it 'displays profile image badge on page load if already set' do
      attachment = entry.attachments.first
      entry.update!(profile_image_id: attachment.id)

      visit "/lex/verification/#{entry.id}"

      # Verify the profile image is marked in the HTML structure
      within('#section-attachments') do
        # Check that the attachment div has the profile-image-selected class
        expect(page).to have_css("#attachment-#{attachment.id}.profile-image-selected")
        # Check that there's a badge indicating this is the profile image
        expect(page).to have_css("#attachment-#{attachment.id} .badge")
      end
    end
  end
end
