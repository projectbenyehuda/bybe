# frozen_string_literal: true

require 'rails_helper'

# The attachments pane's "upload file" button used to be green (btn-success), which read as
# another "mark as verified" action. It is blue (btn-primary) so it no longer competes with them.
RSpec.describe 'Upload button colour in the verification attachments pane', type: :request do
  before { login_as_lexicon_editor }

  shared_examples 'a blue upload button' do |trait|
    let(:entry) { create(:lex_entry, trait, status: :draft) }

    it 'renders the upload button as btn-primary, not btn-success' do
      get lexicon_verification_path(entry)

      section = Nokogiri::HTML(response.body).at_css('#section-attachments')
      upload = section.css('a').find { |a| a.text.strip == I18n.t('lexicon.verification.migrated.upload_file') }

      expect(upload).to be_present
      expect(upload['class'].split).to include('btn-primary')
      expect(upload['class'].split).not_to include('btn-success')
    end
  end

  it_behaves_like 'a blue upload button', :person
  it_behaves_like 'a blue upload button', :publication
end
