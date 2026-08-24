# frozen_string_literal: true

require 'rails_helper'

# Editors used to have to hand-type the <img> tag for an attached image. Both bio editors now
# carry a picker that inserts the tag the migrated entries use, e.g.
#   <img src="/files/lex/3/image004.jpg" data-border="0" data-align="left" data-hspace="10" ... />
RSpec.describe 'Inserting an attached image into a lexicon biography', :js, type: :system do
  let(:person) { create(:lex_person, bio: 'ביוגרפיה קצרה.') }
  let(:entry) { create(:lex_entry, :person, title: 'Test Person', lex_item: person, status: :draft) }

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor

    image_data = Rails.root.join('spec/fixtures/files/test_image.jpg').binread
    entry.attachments.attach(io: StringIO.new(image_data), filename: 'image004.jpg',
                             content_type: 'image/jpeg')
    # Pin the dimensions so the emitted width/height are deterministic. 'analyzed' must be in the
    # metadata JSON, else the helper re-analyzes the blob and overwrites them with the real size.
    blob = entry.attachments.first.blob
    blob.update!(metadata: blob.metadata.merge('analyzed' => true, 'width' => 200, 'height' => 299))
  end

  def bio_textarea_value
    page.evaluate_script("$('#lex_person_bio').val()")
  end

  shared_examples 'a biography image picker' do
    it 'inserts the attached image as a left-floated tag with its real dimensions' do
      # Waiting on the picker's rendered label also waits out the AJAX load of the editor itself.
      expect(page).to have_css('.lex-insert-image .dd-selected-text', text: 'image004.jpg', wait: 10)

      click_button I18n.t('lexicon.shared.insert_image.button')

      expect(page).to have_css('#lex_person_bio', wait: 5)
      expect(bio_textarea_value).to include(
        %(src="/files/lex/#{entry.id}/image004.jpg"),
        'data-border="0"',
        'data-align="left"',
        'data-hspace="10"',
        'width="200"',
        'height="299"'
      )
      # host-independent, so a bio authored in development does not embed localhost
      expect(bio_textarea_value).not_to include('http://')
    end
  end

  describe 'in the migration verification workbench' do
    before do
      entry.start_verification!('test@example.com')
      visit lexicon_verification_path(entry)

      within('#section-bio .section-actions') do
        click_button I18n.t('lexicon.verification.migrated.edit')
      end
    end

    it_behaves_like 'a biography image picker'
  end

  describe 'in the entry-edit properties form' do
    before { visit edit_lexicon_entry_path(entry) }

    it_behaves_like 'a biography image picker'
  end

  describe 'when the entry has no image attachments' do
    before do
      entry.attachments.purge
      visit edit_lexicon_entry_path(entry)
    end

    it 'renders no picker at all' do
      expect(page).to have_css('#properties #lex_person_bio', visible: :visible, wait: 10)
      expect(page).to have_no_css('.lex-insert-image')
    end
  end
end
