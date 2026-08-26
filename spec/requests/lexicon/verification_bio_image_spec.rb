# frozen_string_literal: true

require 'rails_helper'

# An editor inserting an attached image into a biography with the picker used to see it disappear
# from the workbench's bio card: the card rendered the bio through bio_for_display, which strips
# any <img> pointing at the entry's profile image. That strip belongs to the public entry page,
# which renders the portrait separately -- the workbench must show the bio exactly as stored.
RSpec.describe 'Biography image in the verification workbench', type: :request do
  let(:person) { build(:lex_person, bio: 'ביוגרפיה קצרה.') }
  let!(:entry) { create(:lex_entry, :person, status: status, lex_item: person) }
  let(:image_path) { entry.download_path('portrait.jpg') }

  before do
    File.open(Rails.root.join('spec/fixtures/files/test_image.jpg'), 'rb') do |io|
      entry.attachments.attach(
        io: io,
        filename: 'portrait.jpg',
        content_type: 'image/jpeg'
      )
    end
    entry.update!(profile_image_id: entry.attachments.first.id)
    person.update!(bio: %(<img src="#{image_path}" data-align="left" />\n\nביוגרפיה קצרה.))
  end

  describe 'GET /lex/verification/:id' do
    let(:status) { :draft }

    before do
      login_as_lexicon_editor
      entry.start_verification!('test@example.com')
    end

    it 'keeps an image that is also the entry’s profile image' do
      get "/lex/verification/#{entry.id}"

      expect(response).to have_http_status(:success)
      expect(response.body).to include(%(<img src="#{image_path}"))
    end
  end

  describe 'GET the public entry page' do
    let(:status) { :published }

    it 'still strips the inline copy, which it renders as a portrait of its own' do
      get lexicon_entry_path(entry)

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include(%(<img src="#{image_path}"))
      expect(response.body).to include('lexicon-author-pic')
    end
  end
end
